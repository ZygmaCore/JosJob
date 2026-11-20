defmodule JosjobRagpdf.HTTP do
  @moduledoc """
  Thin `Req` wrapper used by providers and the worker.

  All callers inject the client (default `JosjobRagpdf.HTTP`) so tests never touch
  the network. Responses are plain maps:

      %{status: 200, body: term, headers: [{"content-type", "application/json"}]}

  Non-2xx responses are returned as `{:ok, response}`, never raised. Retries
  are handled by `JosjobRagpdf.Retry`, so `Req`'s own retries are disabled here.
  """

  @default_timeout 120_000
  @max_error_length 300

  @type response :: %{
          status: non_neg_integer(),
          body: term(),
          headers: [{String.t(), String.t()}]
        }

  @doc "POST a request. Returns the response map for any HTTP status."
  @spec post(String.t(), keyword()) :: {:ok, response()} | {:error, term()}
  def post(url, opts \\ []) when is_binary(url), do: request(:post, url, opts)

  @doc "GET a request. Returns the response map for any HTTP status."
  @spec get(String.t(), keyword()) :: {:ok, response()} | {:error, term()}
  def get(url, opts \\ []) when is_binary(url), do: request(:get, url, opts)

  @doc """
  Download `url` to `dest_path`, creating parent directories.

  Returns `:ok` on 2xx and `{:error, {:http_status, status}}` otherwise. The
  partial file is removed on failure.
  """
  @spec download(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def download(url, dest_path, opts \\ []) when is_binary(url) and is_binary(dest_path) do
    with :ok <- ensure_parent_dir(dest_path),
         {:ok, response} <- get(url, Keyword.put(opts, :decode, false)) do
      if response.status in 200..299 do
        write_file(dest_path, response.body)
      else
        _ = File.rm(dest_path)
        {:error, {:http_status, response.status}}
      end
    end
  end

  defp write_file(dest_path, body) do
    body = if is_binary(body), do: body, else: ""

    case File.write(dest_path, body) do
      :ok -> :ok
      {:error, reason} -> {:error, {:file_error, reason}}
    end
  end

  defp ensure_parent_dir(dest_path) do
    case dest_path |> Path.dirname() |> File.mkdir_p() do
      :ok -> :ok
      {:error, reason} -> {:error, {:file_error, reason}}
    end
  end

  defp request(method, url, opts) do
    decode? = Keyword.get(opts, :decode, true) != false

    req_opts =
      [method: method, url: url, retry: false, decode_body: false, redirect: true]
      |> Keyword.put(:receive_timeout, timeout(opts))
      |> put_headers(Keyword.get(opts, :headers))
      |> put_body(opts)

    case Req.request(req_opts) do
      {:ok, response} ->
        {:ok, to_map(response, decode?)}

      # Defensive: older/newer Req versions may surface HTTP errors as an
      # exception from the non-bang API. A status is still a valid answer.
      {:error, %{__struct__: Req.HTTPError, response: response}} ->
        {:ok, to_map(response, decode?)}

      {:error, error} ->
        normalize_error(error)
    end
  rescue
    exception ->
      # Never crash the worker because of a malformed URL or bad option.
      {:error, {:request_failed, safe_exception_name(exception)}}
  end

  defp timeout(opts) do
    case Keyword.get(opts, :receive_timeout) do
      value when is_integer(value) and value > 0 -> value
      _ -> @default_timeout
    end
  end

  defp put_headers(req_opts, nil), do: req_opts

  defp put_headers(req_opts, headers) when is_map(headers) do
    Keyword.put(req_opts, :headers, normalize_headers(Map.to_list(headers)))
  end

  defp put_headers(req_opts, headers) when is_list(headers) do
    Keyword.put(req_opts, :headers, normalize_headers(headers))
  end

  defp put_headers(req_opts, _headers), do: req_opts

  defp normalize_headers(headers) do
    Enum.map(headers, fn
      {key, value} -> {to_string(key), header_value(value)}
      other -> {to_string(other), ""}
    end)
  end

  defp put_body(req_opts, opts) do
    cond do
      Keyword.has_key?(opts, :json) ->
        req_opts
        |> Keyword.delete(:body)
        |> Keyword.put(:json, Keyword.get(opts, :json))

      Keyword.has_key?(opts, :body) ->
        Keyword.put(req_opts, :body, Keyword.get(opts, :body))

      true ->
        req_opts
    end
  end

  defp to_map(%{status: status, body: body} = response, decode?) do
    headers = Map.get(response, :headers, [])

    %{
      status: status,
      body: if(decode?, do: decode_body(body, headers), else: body),
      headers: headers_to_list(headers)
    }
  end

  defp headers_to_list(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), header_value(value)} end)
  end

  defp headers_to_list(headers) when is_list(headers) do
    Enum.map(headers, fn
      {key, value} -> {to_string(key), header_value(value)}
      other -> {to_string(other), ""}
    end)
  end

  defp headers_to_list(_headers), do: []

  defp header_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp header_value(value), do: to_string(value)

  defp decode_body(body, _headers) when not is_binary(body), do: body
  defp decode_body("", _headers), do: ""

  defp decode_body(body, headers) do
    if json_content_type?(headers) or json_like?(body) do
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        {:error, _reason} -> body
      end
    else
      body
    end
  end

  defp json_content_type?(headers) do
    headers
    |> headers_to_list()
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == "content-type", do: value
    end)
    |> case do
      nil -> false
      value -> value |> String.downcase() |> String.contains?("json")
    end
  end

  defp json_like?(body) do
    case String.trim_leading(body) do
      <<char, _rest::binary>> when char in [?{, ?[] -> true
      _other -> false
    end
  end

  defp normalize_error(%Req.TransportError{reason: reason}), do: {:error, reason}

  defp normalize_error(%{__struct__: _module} = exception) do
    {:error, {:http_error, safe_exception_name(exception)}}
  end

  defp normalize_error(other), do: {:error, other}

  defp safe_exception_name(%{__struct__: module}) when is_atom(module) do
    module |> inspect() |> String.slice(0, @max_error_length)
  end

  defp safe_exception_name(other) do
    other |> inspect() |> String.slice(0, @max_error_length)
  end
end
