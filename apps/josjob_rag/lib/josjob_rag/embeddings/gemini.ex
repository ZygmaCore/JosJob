defmodule JosjobRag.Embeddings.Gemini do
  @moduledoc """
  Gemini embedding provider.

  Uses `models/{model}:embedContent` for one text and
  `models/{model}:batchEmbedContents` for several, with
  `taskType: SEMANTIC_SIMILARITY` and an explicit `outputDimensionality`
  (1536 by default). The API key is sent only in the `x-goog-api-key` header.

  Verified live on 2026-11-16 against `gemini-embedding-2`: single and batch
  requests return 1536 floats, and related texts score ~0.95 cosine versus
  ~0.65 for unrelated texts.
  """

  require Logger

  @default_base_url "https://generativelanguage.googleapis.com"
  @default_model "gemini-embedding-2"
  @task_type "SEMANTIC_SIMILARITY"
  @max_batch 100
  @default_timeout 60_000

  @doc "Stable provider name stored next to every vector."
  def name, do: "gemini"

  @doc "Configured embedding model."
  def model do
    config()[:model] || @default_model
  end

  @doc "True when an API key is configured (or passed as `:api_key`)."
  def configured?(opts \\ []) do
    key = Keyword.get(opts, :api_key) || config()[:api_key]
    is_binary(key) and String.trim(key) != ""
  end

  @doc """
  Embed texts with Gemini.

  A single text uses `embedContent`; two or more use the batch endpoint. Inputs
  are chunked at 100 requests per call (the provider limit).
  """
  @spec embed_many([String.t()], keyword()) :: {:ok, [[float()]]} | {:error, term()}
  def embed_many([], _opts), do: {:ok, []}

  def embed_many(texts, opts) when is_list(texts) do
    if configured?(opts) do
      texts
      |> Enum.chunk_every(@max_batch)
      |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
        case embed_chunk(chunk, opts) do
          {:ok, vectors} -> {:cont, {:ok, acc ++ vectors}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      {:error, :not_configured}
    end
  end

  defp embed_chunk([text], opts), do: embed_one_request(text, opts)

  defp embed_chunk(texts, opts) do
    requests =
      Enum.map(texts, fn text ->
        %{
          "model" => "models/#{model()}",
          "content" => %{"parts" => [%{"text" => text}]},
          "taskType" => @task_type,
          "outputDimensionality" => dimensions()
        }
      end)

    path = "/v1beta/models/#{model()}:batchEmbedContents"

    with {:ok, body} <- post(path, %{"requests" => requests}, opts),
         embeddings when is_list(embeddings) <- body["embeddings"] do
      vectors =
        Enum.map(embeddings, fn embedding ->
          embedding |> Map.get("values") |> to_vector()
        end)

      if length(vectors) == length(texts) and Enum.all?(vectors, &is_list/1) do
        {:ok, vectors}
      else
        {:error, :invalid_embedding_response}
      end
    else
      nil -> {:error, :missing_embeddings}
      {:error, _reason} = error -> error
      _other -> {:error, :invalid_embedding_response}
    end
  end

  defp embed_one_request(text, opts) do
    path = "/v1beta/models/#{model()}:embedContent"

    body = %{
      "content" => %{"parts" => [%{"text" => text}]},
      "taskType" => @task_type,
      "outputDimensionality" => dimensions()
    }

    with {:ok, response} <- post(path, body, opts),
         values when is_list(values) <- get_in(response, ["embedding", "values"]),
         vector when is_list(vector) <- to_vector(values) do
      {:ok, [vector]}
    else
      nil -> {:error, :missing_embedding}
      {:error, _reason} = error -> error
      _other -> {:error, :invalid_embedding_response}
    end
  end

  defp post(path, body, opts) do
    http = Keyword.get(opts, :http_client, &Req.post/2)
    url = base_url() <> path

    request_opts = [
      headers: [
        {"x-goog-api-key", Keyword.get(opts, :api_key) || config()[:api_key] || ""},
        {"content-type", "application/json"}
      ],
      json: body,
      retry: Keyword.get(opts, :retry, :transient),
      max_retries: Keyword.get(opts, :max_retries, 2),
      receive_timeout: Keyword.get(opts, :receive_timeout, @default_timeout)
    ]

    case http.(url, request_opts) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: response_body}} ->
        {:error, {:gemini_http_error, status, error_message(response_body)}}

      {:error, reason} ->
        {:error, {:gemini_transport_error, reason}}
    end
  rescue
    exception -> {:error, {:gemini_request_failed, Exception.message(exception)}}
  end

  defp to_vector(values) when is_list(values) do
    if values != [] and Enum.all?(values, &is_number/1) do
      Enum.map(values, &(&1 * 1.0))
    else
      nil
    end
  end

  defp to_vector(_values), do: nil

  defp error_message(%{"error" => %{"message" => message}}) when is_binary(message),
    do: String.slice(message, 0, 300)

  defp error_message(%{"error" => error}), do: inspect(error, printable_limit: 300)
  defp error_message(body) when is_binary(body), do: String.slice(body, 0, 300)
  defp error_message(body), do: inspect(body, printable_limit: 300)

  defp base_url do
    (config()[:base_url] || @default_base_url)
    |> String.trim_trailing("/")
  end

  defp dimensions do
    Application.get_env(:josjob_rag, :embeddings, [])[:dimensions] || 1536
  end

  defp config, do: Application.get_env(:josjob_rag, :embeddings, [])
end
