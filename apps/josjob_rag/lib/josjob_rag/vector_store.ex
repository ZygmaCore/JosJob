defmodule JosjobRag.VectorStore do
  @moduledoc """
  pgvector-backed store for job, course, and CV embeddings.

  The table is `rag_embeddings` (migration
  `create_rag_pipeline`) with one row per `(owner_type, owner_id, provider,
  model)` and a `vector(1536)` column. Cosine distance uses pgvector's `<=>`
  operator and an HNSW index.

  The app uses raw SQL on purpose: it avoids adding a new Ecto type dependency
  and keeps the schema explicit. Every function returns `{:error, reason}`
  instead of raising so callers can degrade to skill-only ranking when the
  database is unavailable (useful in local development and tests).

  Owner ids are text, not UUID: jobs and courses use UUIDs, but CV versions come
  from the extraction service and may be opaque strings such as `cv_live_1`.
  """

  require Logger

  @table "rag_embeddings"
  @owner_types ~w(job course cv)
  @default_dimensions 1536
  @timeout 15_000

  @type owner :: :job | :course | :cv | String.t()
  @type space :: %{provider: String.t(), model: String.t(), dimensions: pos_integer()}

  @doc "Configured embedding dimensions (must match the migration)."
  def dimensions do
    Application.get_env(:josjob_rag, :embeddings, [])[:dimensions] || @default_dimensions
  end

  @doc "SHA-256 of the indexed text; used to skip unchanged rows."
  def content_hash(text) when is_binary(text) do
    :crypto.hash(:sha256, text) |> Base.encode16(case: :lower)
  end

  def content_hash(text), do: content_hash(to_string(text || ""))

  @doc """
  Insert or replace one embedding.

  Options: `:provider`, `:model` (strings), and `:content_hash` to avoid
  re-hashing a large text when the caller already did it.
  """
  @spec put(owner(), String.t(), String.t(), [float()], keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def put(owner_type, owner_id, text, vector, opts \\ []) do
    with {:ok, owner_type} <- cast_owner_type(owner_type),
         {:ok, owner_id} <- cast_owner_id(owner_id),
         {:ok, vector} <- validate_vector(vector) do
      provider = to_string(opts[:provider] || "local")
      model = to_string(opts[:model] || "unknown")
      hash = opts[:content_hash] || content_hash(text)
      dimensions = length(vector)

      sql = """
      insert into #{@table}
        (owner_type, owner_id, provider, model, dimensions, content_hash, source_text, embedding, inserted_at, updated_at)
      values
        ($1, $2, $3, $4, $5, $6, $7, $8::text::vector, now(), now())
      on conflict (owner_type, owner_id, provider, model) do update set
        dimensions = excluded.dimensions,
        content_hash = excluded.content_hash,
        source_text = excluded.source_text,
        embedding = excluded.embedding,
        updated_at = now()
      returning id
      """

      case query(sql, [
             owner_type,
             owner_id,
             provider,
             model,
             dimensions,
             hash,
             text,
             format_vector(vector)
           ]) do
        {:ok, [%{"id" => id} | _]} -> {:ok, id}
        {:ok, _rows} -> {:error, :missing_returned_id}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Insert or replace many embeddings. Stops at the first failure."
  @spec put_many([map()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def put_many(rows) when is_list(rows) do
    Enum.reduce_while(rows, {:ok, 0}, fn row, {:ok, count} ->
      case put(
             row[:owner_type] || row["owner_type"],
             row[:owner_id] || row["owner_id"],
             row[:text] || row["text"] || "",
             row[:vector] || row["vector"],
             provider: row[:provider] || row["provider"],
             model: row[:model] || row["model"],
             content_hash: row[:content_hash] || row["content_hash"]
           ) do
        {:ok, _id} -> {:cont, {:ok, count + 1}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Fetch one embedding.

  Options `:provider` and `:model` narrow the lookup; without them the newest
  row for the owner is returned.
  """
  @spec get(owner(), String.t(), keyword()) :: {:ok, map()} | {:error, :not_found | term()}
  def get(owner_type, owner_id, opts \\ []) do
    with {:ok, owner_type} <- cast_owner_type(owner_type),
         {:ok, owner_id} <- cast_owner_id(owner_id) do
      {where, params} =
        space_filter("owner_type = $1 and owner_id = $2", [owner_type, owner_id], opts, 3)

      sql = """
      select id, owner_type, owner_id, provider, model, dimensions, content_hash,
             source_text, embedding::text as embedding, inserted_at, updated_at
      from #{@table}
      where #{where}
      order by updated_at desc
      limit 1
      """

      case query(sql, params) do
        {:ok, [row | _]} -> {:ok, decode_row(row)}
        {:ok, []} -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Content hashes for a batch of owners in one space."
  @spec hashes(owner(), [String.t()], String.t(), String.t()) ::
          {:ok, %{String.t() => String.t()}} | {:error, term()}
  def hashes(owner_type, owner_ids, provider, model) do
    with {:ok, owner_type} <- cast_owner_type(owner_type),
         {:ok, owner_ids} <- cast_owner_ids(owner_ids) do
      if owner_ids == [] do
        {:ok, %{}}
      else
        sql = """
        select owner_id, content_hash
        from #{@table}
        where owner_type = $1 and owner_id = any($2::text[])
          and provider = $3 and model = $4
        """

        case query(sql, [owner_type, owner_ids, to_string(provider), to_string(model)]) do
          {:ok, rows} -> {:ok, Map.new(rows, &{&1["owner_id"], &1["content_hash"]})}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  @doc "Vectors for a batch of owners in one space, keyed by owner id."
  @spec vectors(owner(), [String.t()], String.t(), String.t()) ::
          {:ok, %{String.t() => [float()]}} | {:error, term()}
  def vectors(owner_type, owner_ids, provider, model) do
    with {:ok, owner_type} <- cast_owner_type(owner_type),
         {:ok, owner_ids} <- cast_owner_ids(owner_ids) do
      if owner_ids == [] do
        {:ok, %{}}
      else
        sql = """
        select owner_id, embedding::text as embedding
        from #{@table}
        where owner_type = $1 and owner_id = any($2::text[])
          and provider = $3 and model = $4
        """

        case query(sql, [owner_type, owner_ids, to_string(provider), to_string(model)]) do
          {:ok, rows} ->
            {:ok, Map.new(rows, &{&1["owner_id"], parse_vector(&1["embedding"])})}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  @doc """
  Nearest owners by cosine similarity, highest similarity first.

  Options: `:provider`, `:model`, `:limit` (default 50), `:min_similarity`.
  Similarity is `1 - cosine_distance` and may be negative for opposite vectors.
  """
  @spec nearest(owner(), [float()], keyword()) :: {:ok, [map()]} | {:error, term()}
  def nearest(owner_type, vector, opts \\ []) do
    with {:ok, owner_type} <- cast_owner_type(owner_type),
         {:ok, vector} <- validate_vector(vector) do
      limit = opts[:limit] || 50
      {space_sql, params} = space_filter("owner_type = $2", [owner_type], opts, 3)
      limit_index = length(params) + 2

      sql = """
      select owner_id, provider, model, 1 - (embedding <=> $1::text::vector) as similarity
      from #{@table}
      where #{space_sql}
      order by embedding <=> $1::text::vector
      limit $#{limit_index}
      """

      case query(sql, [format_vector(vector) | params] ++ [limit]) do
        {:ok, rows} ->
          results =
            rows
            |> Enum.map(fn row ->
              %{
                owner_id: row["owner_id"],
                provider: row["provider"],
                model: row["model"],
                similarity: to_float(row["similarity"])
              }
            end)
            |> filter_min_similarity(opts[:min_similarity])

          {:ok, results}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Distinct embedding spaces present for an owner type, most populated first."
  @spec spaces(owner()) :: {:ok, [space()]} | {:error, term()}
  def spaces(owner_type) do
    with {:ok, owner_type} <- cast_owner_type(owner_type) do
      sql = """
      select provider, model, dimensions, count(*)::int as count
      from #{@table}
      where owner_type = $1
      group by provider, model, dimensions
      order by count desc, provider asc, model asc
      """

      case query(sql, [owner_type]) do
        {:ok, rows} ->
          {:ok,
           Enum.map(rows, fn row ->
             %{
               provider: row["provider"],
               model: row["model"],
               dimensions: row["dimensions"],
               count: row["count"]
             }
           end)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Most populated space for an owner type, or `nil`."
  @spec dominant_space(owner()) :: {:ok, space() | nil} | {:error, term()}
  def dominant_space(owner_type) do
    case spaces(owner_type) do
      {:ok, [space | _]} -> {:ok, space}
      {:ok, []} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Delete every embedding for an owner (all spaces)."
  @spec delete(owner(), String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def delete(owner_type, owner_id) do
    with {:ok, owner_type} <- cast_owner_type(owner_type),
         {:ok, owner_id} <- cast_owner_id(owner_id) do
      sql = "delete from #{@table} where owner_type = $1 and owner_id = $2 returning id"

      case query(sql, [owner_type, owner_id]) do
        {:ok, rows} -> {:ok, length(rows)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Delete one space for an owner (used by forced reindexing)."
  @spec delete_space(owner(), String.t(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def delete_space(owner_type, provider, model) do
    with {:ok, owner_type} <- cast_owner_type(owner_type) do
      sql =
        "delete from #{@table} where owner_type = $1 and provider = $2 and model = $3 returning id"

      case query(sql, [owner_type, to_string(provider), to_string(model)]) do
        {:ok, rows} -> {:ok, length(rows)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Number of stored embeddings, optionally per owner type."
  @spec count(owner() | nil) :: {:ok, non_neg_integer()} | {:error, term()}
  def count(owner_type \\ nil)

  def count(nil) do
    case query("select count(*)::int as count from #{@table}", []) do
      {:ok, [%{"count" => count} | _]} -> {:ok, count}
      {:ok, _} -> {:ok, 0}
      {:error, reason} -> {:error, reason}
    end
  end

  def count(owner_type) do
    with {:ok, owner_type} <- cast_owner_type(owner_type) do
      case query("select count(*)::int as count from #{@table} where owner_type = $1", [
             owner_type
           ]) do
        {:ok, [%{"count" => count} | _]} -> {:ok, count}
        {:ok, _} -> {:ok, 0}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "True when the table exists and is queryable."
  def available? do
    match?({:ok, _}, count())
  end

  # --- pure helpers -------------------------------------------------------

  @doc "pgvector text format: `[1.0,0.5,-0.25]`."
  @spec format_vector([number()]) :: String.t()
  def format_vector(vector) when is_list(vector) do
    "[" <> Enum.map_join(vector, ",", &format_number/1) <> "]"
  end

  @doc "Parse pgvector text output back into floats."
  @spec parse_vector(term()) :: [float()]
  def parse_vector(nil), do: []

  def parse_vector("[]"), do: []

  def parse_vector("[" <> rest = _value) do
    rest
    |> String.trim_trailing("]")
    |> String.split(",", trim: true)
    |> Enum.map(fn value ->
      case Float.parse(String.trim(value)) do
        {float, _rest} -> float
        :error -> 0.0
      end
    end)
  end

  def parse_vector(value) when is_list(value), do: Enum.map(value, &to_float/1)
  def parse_vector(_value), do: []

  # --- internals ----------------------------------------------------------

  defp query(sql, params) do
    case Ecto.Adapters.SQL.query(Josjob.Repo, sql, params, timeout: @timeout) do
      {:ok, %{columns: columns, rows: rows}} ->
        # Statements without `RETURNING` report `rows: nil`.
        {:ok, Enum.map(rows || [], fn row -> Map.new(Enum.zip(columns || [], row)) end)}

      {:error, reason} ->
        {:error, normalize_error(reason)}
    end
  rescue
    exception ->
      {:error, {:store_unavailable, Exception.message(exception)}}
  catch
    :exit, reason ->
      {:error, {:store_unavailable, reason}}
  end

  defp normalize_error(%Postgrex.Error{postgres: %{code: :undefined_table}}),
    do: :not_migrated

  defp normalize_error(%Postgrex.Error{postgres: %{code: :undefined_column}}),
    do: :not_migrated

  defp normalize_error(%Postgrex.Error{message: message}), do: {:postgres, message}

  defp normalize_error(%{__exception__: true} = error),
    do: {:store_unavailable, Exception.message(error)}

  defp normalize_error(reason), do: {:store_unavailable, reason}

  defp space_filter(base, params, opts, position) do
    provider = opts[:provider]
    model = opts[:model]

    cond do
      provider && model ->
        {base <> " and provider = $#{position} and model = $#{position + 1}",
         params ++ [to_string(provider), to_string(model)]}

      provider ->
        {base <> " and provider = $#{position}", params ++ [to_string(provider)]}

      model ->
        {base <> " and model = $#{position}", params ++ [to_string(model)]}

      true ->
        {base, params}
    end
  end

  defp decode_row(row) do
    %{
      id: row["id"],
      owner_type: row["owner_type"],
      owner_id: row["owner_id"],
      provider: row["provider"],
      model: row["model"],
      dimensions: row["dimensions"],
      content_hash: row["content_hash"],
      source_text: row["source_text"],
      embedding: parse_vector(row["embedding"]),
      inserted_at: row["inserted_at"],
      updated_at: row["updated_at"]
    }
  end

  defp validate_vector(vector) when is_list(vector) do
    cond do
      vector == [] -> {:error, :empty_vector}
      length(vector) != dimensions() -> {:error, {:invalid_dimensions, length(vector)}}
      not Enum.all?(vector, &is_number/1) -> {:error, :invalid_vector}
      true -> {:ok, Enum.map(vector, &to_float/1)}
    end
  end

  defp validate_vector(_vector), do: {:error, :invalid_vector}

  defp cast_owner_type(type) do
    type = to_string(type)

    if type in @owner_types do
      {:ok, type}
    else
      {:error, {:invalid_owner_type, type}}
    end
  end

  defp cast_owner_id(id) when is_binary(id) do
    case String.trim(id) do
      "" -> {:error, :invalid_owner_id}
      trimmed -> {:ok, trimmed}
    end
  end

  defp cast_owner_id(id) when is_integer(id), do: {:ok, Integer.to_string(id)}
  defp cast_owner_id(_id), do: {:error, :invalid_owner_id}

  defp cast_owner_ids(ids) when is_list(ids) do
    ids =
      ids
      |> Enum.map(&cast_owner_id/1)
      |> Enum.flat_map(fn
        {:ok, id} -> [id]
        _ -> []
      end)
      |> Enum.uniq()

    {:ok, ids}
  end

  defp cast_owner_ids(ids), do: cast_owner_ids(List.wrap(ids))

  defp format_number(value) when is_integer(value), do: Integer.to_string(value)
  defp format_number(value) when is_float(value), do: :erlang.float_to_binary(value, [:short])
  defp format_number(value) when is_number(value), do: to_string(value)

  defp filter_min_similarity(rows, nil), do: rows
  defp filter_min_similarity(rows, min), do: Enum.filter(rows, &(&1.similarity >= min))

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value * 1.0
  defp to_float(_value), do: 0.0
end
