defmodule JosjobRag.Indexer do
  @moduledoc """
  Orchestrates the ingestion, database setup, and document upload to the Atomic Server.
  """

  require Logger
  require Ash.Query

  alias JosjobRag.Extractor
  alias JosjobRag.AtomicClient

  @doc """
  Ingests a document file from `file_path` for a given course and user.
  """
  def ingest(file_path, filename, course_id, user_id) do
    Logger.info("Starting ingestion of #{filename} for course #{course_id} by user #{user_id}")

    # 1. Lookup organization
    org_id = get_user_organization_id(user_id)
    db_id = "db_#{org_id}_#{course_id}"
    Logger.info("Target database: #{db_id}")

    # 2. Extract text from file
    with {:ok, text} <- Extractor.extract(file_path),
         # 3. Ensure database exists
         :ok <- ensure_database_exists(db_id),
         # 4. Upload document atom
         {:ok, response} <- AtomicClient.create_atom(db_id, filename, text) do
      Logger.info("Successfully ingested #{filename} to Atomic Server")
      {:ok, response}
    else
      {:error, reason} ->
        Logger.error("Failed to ingest #{filename}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Lookup organization ID for the given user, with safe fallbacks.
  """
  def get_user_organization_id(user_id) do
    case Josjob.Orgs.Membership
         |> Ash.Query.filter(user_id == ^user_id and status == :active)
         |> Ash.read(authorize?: false) do
      {:ok, [membership | _]} ->
        membership.organization_id

      _ ->
        case Josjob.Orgs.Organization |> Ash.read(authorize?: false) do
          {:ok, [org | _]} -> org.id
          _ -> "default_org"
        end
    end
  rescue
    e ->
      Logger.error("Error retrieving user organization: #{inspect(e)}")
      "default_org"
  end

  # Helper to ensure database is created on the Atomic Server
  defp ensure_database_exists(db_id) do
    case AtomicClient.list_databases() do
      {:ok, list} ->
        db_ids = extract_db_ids(list)

        if db_id in db_ids do
          Logger.info("Database #{db_id} already exists on Atomic Server")
          :ok
        else
          case AtomicClient.create_database(db_id) do
            {:ok, _} -> :ok
            {:error, reason} -> {:error, {:create_db_failed, reason}}
          end
        end

      {:error, reason} ->
        Logger.warning(
          "Could not verify database list: #{inspect(reason)}. Attempting creation directly."
        )

        case AtomicClient.create_database(db_id) do
          {:ok, _} -> :ok
          # If it returns a 409 conflict, it means database already exists
          {:error, {:unexpected_status, 409}} -> :ok
          {:error, reason} -> {:error, {:create_db_failed, reason}}
        end
    end
  end

  # Extracts database IDs from various list shapes
  defp extract_db_ids(list) when is_list(list) do
    Enum.map(list, fn
      %{"id" => id} -> id
      %{id: id} -> id
      id when is_binary(id) -> id
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_db_ids(%{"databases" => list}) when is_list(list), do: extract_db_ids(list)
  defp extract_db_ids(%{databases: list}) when is_list(list), do: extract_db_ids(list)
  defp extract_db_ids(_), do: []
end
