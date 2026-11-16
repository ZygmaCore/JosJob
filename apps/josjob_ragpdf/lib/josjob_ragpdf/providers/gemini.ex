defmodule JosjobRagpdf.Providers.Gemini do
  @moduledoc """
  Google Gemini provider (PDF first).

  Sends the PDF inline as base64 to `generateContent` together with a fixed
  system instruction and a chunk prompt. The API key travels in the
  `x-goog-api-key` header only, never in the URL.

  Configuration (`Application.get_env(:josjob_ragpdf, :gemini)` or `opts[:config]`):

    * `:base_url` — default `https://generativelanguage.googleapis.com`
    * `:model` — default `gemini-3.5-flash`
    * `:api_key` — required, otherwise `{:error, :not_configured}`
    * `:timeout_ms`, `:max_attempts`, `:base_delay_ms`, `:max_delay_ms`

  The API key, PDF bytes and extracted text are never logged.
  """

  @behaviour JosjobRagpdf.Provider

  @default_base_url "https://generativelanguage.googleapis.com"
  @default_model "gemini-3.5-flash"
  @default_timeout_ms 120_000
  @default_max_attempts 3
  @default_base_delay_ms 1_000
  @default_max_delay_ms 10_000

  @api_version "v1beta"
  @max_safe_body 300

  @retryable_reasons [
    :timeout,
    :econnrefused,
    :closed,
    :econnreset,
    :nxdomain,
    :enetunreach,
    :ehostunreach
  ]

  @impl true
  def extract_pdf(path, opts \\ []) when is_binary(path) do
    with {:ok, config} <- config(opts),
         {:ok, data} <- read_pdf(path) do
      media = [
        %{
          "inline_data" => %{
            "mime_type" => "application/pdf",
            "data" => Base.encode64(data)
          }
        }
      ]

      request(config, opts, media)
    end
  end

  @impl true
  def extract_text(text, opts \\ []) when is_binary(text) do
    with {:ok, config} <- config(opts) do
      media = [%{"text" => JosjobRagpdf.Prompt.sanitize_text(text)}]
      request(config, opts, media)
    end
  end

  defp read_pdf(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:file_error, reason}}
    end
  end

  defp request(config, opts, media_parts) do
    url = "#{config.base_url}/#{@api_version}/models/#{config.model}:generateContent"
    client = http_client(opts)

    http_opts = [
      headers: [
        {"x-goog-api-key", config.api_key},
        {"content-type", "application/json"}
      ],
      json: request_body(opts, media_parts),
      receive_timeout: config.timeout_ms
    ]

    result =
      JosjobRagpdf.Retry.with_retry(
        fn -> client.post(url, http_opts) end,
        max_attempts: config.max_attempts,
        base_delay_ms: config.base_delay_ms,
        max_delay_ms: config.max_delay_ms,
        retryable: &retryable?/1
      )

    handle_response(result, config)
  end

  defp request_body(opts, media_parts) do
    prompt = JosjobRagpdf.Prompt.chunk(prompt_context(opts))

    %{
      "systemInstruction" => %{"parts" => [%{"text" => JosjobRagpdf.Prompt.system()}]},
      "contents" => [
        %{"role" => "user", "parts" => [%{"text" => prompt} | media_parts]}
      ],
      "generationConfig" => %{
        "response_mime_type" => "application/json",
        "response_schema" => JosjobRagpdf.Prompt.schema()
      }
    }
  end

  defp prompt_context(opts) do
    %{
      index: opts[:index],
      total: opts[:total],
      filename: opts[:filename],
      known_skills: opts[:known_skills] || []
    }
  end

  defp handle_response({:ok, %{status: status, body: body}}, config)
       when is_integer(status) and status in 200..299 do
    case parse_completion(body) do
      {:ok, result, usage} ->
        {:ok, result, %{provider: "gemini", model: config.model, usage: usage}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}, config) when is_integer(status) do
    {:error, {:http_status, status, safe_body(body, config.api_key)}}
  end

  defp handle_response({:error, reason}, _config), do: {:error, normalize_error(reason)}

  defp handle_response(_other, _config), do: {:error, {:invalid_response, :http}}

  defp parse_completion(body) do
    with {:ok, decoded} <- decode_body(body),
         {:ok, text} <- completion_text(decoded),
         {:ok, result} <- decode_result(text) do
      {:ok, result, usage(decoded)}
    end
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{} = decoded} -> {:ok, decoded}
      {:ok, _other} -> {:error, {:invalid_response, :not_an_object}}
      {:error, _reason} -> {:error, {:invalid_response, :invalid_json}}
    end
  end

  defp decode_body(_body), do: {:error, {:invalid_response, :empty_body}}

  defp completion_text(decoded) do
    candidate =
      case decoded["candidates"] do
        [first | _rest] when is_map(first) -> first
        _other -> nil
      end

    parts =
      case candidate do
        %{"content" => %{"parts" => parts}} when is_list(parts) -> parts
        _other -> []
      end

    text =
      parts
      |> Enum.map(fn
        %{"text" => text} when is_binary(text) -> text
        _part -> ""
      end)
      |> Enum.join()

    cond do
      String.trim(text) != "" ->
        {:ok, text}

      candidate != nil ->
        {:error, {:invalid_response, :empty_completion}}

      true ->
        case block_reason(decoded) do
          nil -> {:error, {:invalid_response, :no_candidates}}
          reason -> {:error, {:blocked, reason}}
        end
    end
  end

  defp decode_result(text) do
    case Jason.decode(text) do
      {:ok, %{} = result} -> {:ok, result}
      {:ok, _other} -> {:error, {:invalid_response, :not_an_object}}
      {:error, _reason} -> {:error, {:invalid_response, :invalid_json}}
    end
  end

  defp block_reason(decoded) do
    case decoded["promptFeedback"] do
      %{"blockReason" => reason} when is_binary(reason) -> String.slice(reason, 0, 80)
      _other -> nil
    end
  end

  defp usage(%{"usageMetadata" => usage}) when is_map(usage), do: usage
  defp usage(_decoded), do: nil

  defp retryable?({:ok, %{status: status}}) when is_integer(status) do
    status == 429 or status == 408 or status >= 500
  end

  defp retryable?({:error, reason}) when reason in @retryable_reasons, do: true
  defp retryable?(_result), do: false

  defp normalize_error(reason) when is_atom(reason), do: reason
  defp normalize_error({tag, _detail} = reason) when is_atom(tag), do: reason
  defp normalize_error(reason) when is_binary(reason), do: String.slice(reason, 0, @max_safe_body)
  defp normalize_error(_reason), do: :transport_error

  defp safe_body(body, key) do
    raw =
      if is_binary(body) do
        body
      else
        inspect(body, limit: 50, printable_limit: @max_safe_body * 2)
      end

    raw
    |> redact(key)
    |> String.slice(0, @max_safe_body)
  end

  defp redact(text, key) when is_binary(key) and key != "" do
    String.replace(text, key, "[redacted]")
  end

  defp redact(text, _key), do: text

  defp http_client(opts) do
    opts[:http_client] || Application.get_env(:josjob_ragpdf, :http_client, JosjobRagpdf.HTTP)
  end

  defp config(opts) do
    merged =
      Application.get_env(:josjob_ragpdf, :gemini, [])
      |> to_map()
      |> Map.merge(to_map(opts[:config]))

    case normalize_string(get_setting(merged, :api_key)) do
      nil ->
        {:error, :not_configured}

      api_key ->
        {:ok,
         %{
           api_key: api_key,
           base_url: base_url(merged),
           model: model(merged),
           timeout_ms: integer_setting(merged, :timeout_ms, @default_timeout_ms, 1),
           max_attempts: integer_setting(merged, :max_attempts, @default_max_attempts, 1),
           base_delay_ms: integer_setting(merged, :base_delay_ms, @default_base_delay_ms, 0),
           max_delay_ms: integer_setting(merged, :max_delay_ms, @default_max_delay_ms, 0)
         }}
    end
  end

  defp base_url(merged) do
    case merged |> get_setting(:base_url) |> normalize_string() do
      nil -> @default_base_url
      url -> String.trim_trailing(url, "/")
    end
  end

  defp model(merged) do
    case merged |> get_setting(:model) |> normalize_string() do
      nil -> @default_model
      model -> model
    end
  end

  defp to_map(config) when is_map(config), do: config
  defp to_map(config) when is_list(config), do: Map.new(config)
  defp to_map(_config), do: %{}

  defp get_setting(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp normalize_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_string(_value), do: nil

  defp integer_setting(map, key, default, minimum) do
    case get_setting(map, key) do
      value when is_integer(value) and value >= minimum -> value
      _value -> default
    end
  end
end
