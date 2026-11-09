defmodule StellarRag.AtomicClient do
  @moduledoc """
  API client for communicating with the Atomic Server (https://stellar-rag.onprem.vip).
  Documentation: https://atomicapp.ai/api/explorer
  """

  require Logger

  @doc """
  Gets the atomic config.
  """
  def config do
    Application.get_env(:stellar_rag, :atomic, [])
  end

  @doc """
  Gets the configured base URL.
  """
  def base_url do
    Keyword.get(config(), :base_url, "https://stellar-rag.onprem.vip")
  end

  @doc """
  Gets the configured API token.
  """
  def api_token do
    Keyword.get(config(), :api_token, "default_token")
  end

  @doc """
  Prepares headers for API requests.
  """
  def headers(db_id \\ nil) do
    base_headers = [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{api_token()}"}
    ]

    if db_id do
      base_headers ++ [{"x-atomic-database", db_id}]
    else
      base_headers
    end
  end

  @doc """
  List all databases on the Atomic Server.
  """
  def list_databases do
    url = "#{base_url()}/api/databases"
    Logger.info("Listing databases from Atomic Server: #{url}")

    case Req.get(url, headers: headers()) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        # Body could be a list of databases or a map containing a list
        {:ok, body}

      {:ok, response} ->
        Logger.error(
          "Failed to list databases, status: #{response.status}, body: #{inspect(response.body)}"
        )

        {:error, {:unexpected_status, response.status}}

      {:error, reason} ->
        Logger.error("HTTP request error listing databases: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Create a database on the Atomic Server.
  """
  def create_database(db_id) do
    url = "#{base_url()}/api/databases"
    Logger.info("Creating database #{db_id} on Atomic Server: #{url}")

    body = %{
      id: db_id,
      name: db_id
    }

    case Req.post(url, json: body, headers: headers()) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        Logger.info("Successfully created database #{db_id}")
        {:ok, body}

      {:ok, response} ->
        Logger.error(
          "Failed to create database #{db_id}, status: #{response.status}, body: #{inspect(response.body)}"
        )

        {:error, {:unexpected_status, response.status}}

      {:error, reason} ->
        Logger.error("HTTP request error creating database #{db_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  List atoms (documents) inside a database.
  """
  def list_atoms(db_id) do
    url = "#{base_url()}/api/atoms"
    Logger.info("Listing atoms inside database #{db_id} from Atomic Server")

    case Req.get(url, params: [db: db_id], headers: headers(db_id)) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        # Return atoms
        {:ok, body}

      {:ok, response} ->
        Logger.error(
          "Failed to list atoms for database #{db_id}, status: #{response.status}, body: #{inspect(response.body)}"
        )

        {:error, {:unexpected_status, response.status}}

      {:error, reason} ->
        Logger.error("HTTP request error listing atoms for database #{db_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Create an atom (document) inside a database.
  """
  def create_atom(db_id, title, content) do
    url = "#{base_url()}/api/atoms"
    Logger.info("Creating atom '#{title}' in database #{db_id} on Atomic Server")

    body = %{
      title: title,
      content: content
    }

    case Req.post(url, params: [db: db_id], json: body, headers: headers(db_id)) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        Logger.info("Successfully created atom '#{title}' in database #{db_id}")
        {:ok, body}

      {:ok, response} ->
        Logger.error(
          "Failed to create atom in database #{db_id}, status: #{response.status}, body: #{inspect(response.body)}"
        )

        {:error, {:unexpected_status, response.status}}

      {:error, reason} ->
        Logger.error("HTTP request error creating atom in database #{db_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Delete an atom (document) by its ID or title.
  Since atomic uses resource-based deletion:
  `DELETE /api/atoms/{id}`
  """
  def delete_atom(db_id, atom_id) do
    url = "#{base_url()}/api/atoms/#{atom_id}"
    Logger.info("Deleting atom #{atom_id} in database #{db_id}")

    case Req.delete(url, params: [db: db_id], headers: headers(db_id)) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        Logger.info("Successfully deleted atom #{atom_id}")
        {:ok, body}

      {:ok, response} ->
        Logger.error("Failed to delete atom #{atom_id}, status: #{response.status}")
        {:error, {:unexpected_status, response.status}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
