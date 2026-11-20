defmodule JosjobRag.PdfClient do
  @moduledoc """
  HTTP client for the standalone CV extraction service (`apps/josjob_ragpdf`).

  The extraction service is deliberately not part of the umbrella: it owns PDF
  parsing and LLM calls, while the backend owns ranking and persistence. The
  service stores jobs in memory, so a restart loses unfinished extractions.

  Config (`config :josjob_rag, :pdf_service`): `:base_url`, `:api_token`,
  `:receive_timeout`.
  """

  @default_base_url "http://localhost:4010"
  @default_timeout 120_000

  @doc "Submit an uploaded PDF for extraction."
  @spec submit_upload(map(), String.t(), String.t() | nil, keyword()) ::
          {:ok, map()} | {:error, term()}
  def submit_upload(upload, user_id, cv_id, opts \\ [])

  def submit_upload(%{path: path, filename: filename} = upload, user_id, cv_id, opts) do
    content_type = Map.get(upload, :content_type) || "application/pdf"

    # Read the upload into memory instead of streaming it. Req streams unknown
    # length bodies as chunked requests, and Bandit (the ragpdf service) closes
    # those with "Body read timeout" before the parser finishes. Uploads are
    # capped at `max_pdf_bytes` (10 MB), so a binary body is safe and lets Req
    # send a `content-length` header.
    case File.read(path) do
      {:ok, data} ->
        form =
          [
            user_id: to_string(user_id),
            cv_id: cv_id,
            filename: filename,
            idempotency_key: opts[:idempotency_key],
            file: {data, filename: filename || "cv.pdf", content_type: content_type}
          ]
          |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)

        post("/v1/cv/analyses", [form_multipart: form], opts)

      {:error, reason} ->
        {:error, {:file_error, reason}}
    end
  end

  def submit_upload(_upload, _user_id, _cv_id, _opts), do: {:error, :missing_file}

  @doc "Submit a PDF/JSON extraction request without a local upload."
  @spec submit(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def submit(payload, opts \\ []) when is_map(payload) do
    post("/v1/cv/analyses", [json: payload], opts)
  end

  @doc "Fetch one extraction job and its result."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(id, opts \\ []) when is_binary(id) do
    request(:get, "/v1/cv/analyses/" <> URI.encode_www_form(id), [], opts)
  end

  @doc "Cancel/delete an extraction job."
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(id, opts \\ []) when is_binary(id) do
    request(:delete, "/v1/cv/analyses/" <> URI.encode_www_form(id), [], opts)
  end

  @doc "Queue statistics (service auth applies)."
  @spec queue(keyword()) :: {:ok, map()} | {:error, term()}
  def queue(opts \\ []), do: request(:get, "/v1/queue", [], opts)

  @doc "Liveness check; `/health` is public."
  @spec health(keyword()) :: {:ok, map()} | {:error, term()}
  def health(opts \\ []), do: request(:get, "/health", [], Keyword.put(opts, :auth, false))

  @doc "True when a base URL is configured."
  def configured? do
    is_binary(base_url()) and String.trim(base_url()) != ""
  end

  defp post(path, req_options, opts) do
    request(:post, path, req_options, opts)
  end

  defp request(method, path, req_options, opts) do
    http = Keyword.get(opts, :http_client, &Req.request/1)

    request =
      ([
         method: method,
         base_url: base_url(),
         url: path,
         receive_timeout: Keyword.get(opts, :receive_timeout, timeout()),
         retry: Keyword.get(opts, :retry, :transient)
       ] ++ req_options)
      |> maybe_put_auth(opts)

    case http.(request) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:ragpdf, status, body}}

      {:error, reason} ->
        {:error, {:ragpdf_transport, reason}}
    end
  rescue
    exception -> {:error, {:ragpdf_transport, Exception.message(exception)}}
  end

  defp maybe_put_auth(request, opts) do
    token = Keyword.get(opts, :api_token, config()[:api_token])

    if Keyword.get(opts, :auth, true) and is_binary(token) and String.trim(token) != "" do
      Keyword.put(request, :auth, {:bearer, token})
    else
      request
    end
  end

  defp base_url do
    (config()[:base_url] || @default_base_url)
    |> String.trim_trailing("/")
  end

  defp timeout, do: config()[:receive_timeout] || @default_timeout

  defp config, do: Application.get_env(:josjob_rag, :pdf_service, [])
end
