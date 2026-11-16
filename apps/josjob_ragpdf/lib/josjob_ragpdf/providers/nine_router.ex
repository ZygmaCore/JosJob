defmodule JosjobRagpdf.Providers.NineRouter do
  @moduledoc """
  OpenAI-compatible provider used as a blind fallback (9Router).

  NineRouter speaks `POST {base_url}/chat/completions`, so the PDF is first
  converted to text with `JosjobRagpdf.Pdf.text/1` and then sent as a chat message.
  There is no real server in tests; the module is exercised through an
  injected HTTP client.

  Configuration (`Application.get_env(:josjob_ragpdf, :nine_router)` or
  `opts[:config]`): `:base_url` and `:model` are required, `:api_key` is
  optional, plus `:timeout_ms`, `:max_attempts`, `:base_delay_ms`,
  `:max_delay_ms`.
  """

  @behaviour JosjobRagpdf.Provider

  @default_timeout_ms 120_000
  @default_max_attempts 2
  @default_base_delay_ms 1_000
  @default_max_delay_ms 10_000

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
    case JosjobRagpdf.Pdf.text(path) do
      {:ok, text} ->
        if blank?(text), do: {:error, :no_text}, else: extract_text(text, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def extract_text(text, opts \\ []) when is_binary(text) do
    text = text |> JosjobRagpdf.Prompt.sanitize_text() |> String.trim()

    with :ok <- ensure_text(text),
         {:ok, config} <- config(opts) do
      request(config, opts, text)
    end
  end

  defp ensure_text(text) do
    if blank?(text), do: {:error, :no_text}, else: :ok
  end

  defp blank?(text), do: String.trim(text) == ""

  defp request(config, opts, text) do
    url = "#{config.base_url}/chat/completions"
    client = http_client(opts)

    http_opts = [
      headers: headers(config),
      json: request_body(config, opts, text),
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

  defp headers(config) do
    base = [{"content-type", "application/json"}]

    case config.api_key do
      nil -> base
      key -> [{"authorization", "Bearer " <> key} | base]
    end
  end

  defp request_body(config, opts, text) do
    %{
      "model" => config.model,
      "messages" => [
        %{"role" => "system", "content" => JosjobRagpdf.Prompt.system()},
        %{"role" => "user", "content" => user_content(opts, text)}
      ],
      "response_format" => %{"type" => "json_object"},
      "temperature" => 0
    }
  end

  defp user_content(opts, text) do
    prompt =
      JosjobRagpdf.Prompt.chunk(%{
        index: opts[:index],
        total: opts[:total],
        filename: opts[:filename],
        known_skills: opts[:known_skills] || []
      })

    prompt <> "\n--- CV TEXT ---\n" <> text
  end

  defp handle_response({:ok, %{status: status, body: body}}, config)
       when is_integer(status) and status in 200..299 do
    case parse_completion(body) do
      {:ok, result, usage} ->
        {:ok, result, %{provider: "nine_router", model: config.model, usage: usage}}

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
         {:ok, content} <- message_content(decoded),
         {:ok, text} <- content_text(content),
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

  defp message_content(decoded) do
    case decoded["choices"] do
      [first | _rest] when is_map(first) ->
        case first["message"] do
          %{"content" => content} -> {:ok, content}
          _other -> {:error, {:invalid_response, :no_content}}
        end

      _other ->
        {:error, {:invalid_response, :no_choices}}
    end
  end

  defp content_text(content) when is_binary(content) do
    case String.trim(content) do
      "" -> {:error, {:invalid_response, :empty_completion}}
      text -> {:ok, text}
    end
  end

  defp content_text(content) when is_list(content) do
    text =
      content
      |> Enum.map(fn
        %{"text" => text} when is_binary(text) -> text
        _part -> ""
      end)
      |> Enum.join()

    content_text(text)
  end

  defp content_text(_content), do: {:error, {:invalid_response, :empty_completion}}

  defp decode_result(text) do
    case Jason.decode(strip_code_fence(text)) do
      {:ok, %{} = result} -> {:ok, result}
      {:ok, _other} -> {:error, {:invalid_response, :not_an_object}}
      {:error, _reason} -> {:error, {:invalid_response, :invalid_json}}
    end
  end

  # Some OpenAI-compatible servers wrap JSON in markdown fences even when
  # response_format is json_object.
  defp strip_code_fence(text) do
    trimmed = String.trim(text)

    if String.starts_with?(trimmed, "```") do
      trimmed
      |> String.replace(~r/\A```[a-zA-Z]*\s*/, "")
      |> String.replace(~r/\s*```\z/, "")
      |> String.trim()
    else
      trimmed
    end
  end

  defp usage(%{"usage" => usage}) when is_map(usage), do: usage
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
      Application.get_env(:josjob_ragpdf, :nine_router, [])
      |> to_map()
      |> Map.merge(to_map(opts[:config]))

    base_url = merged |> get_setting(:base_url) |> normalize_string() |> strip_trailing_slash()
    model = merged |> get_setting(:model) |> normalize_string()

    if is_nil(base_url) or is_nil(model) do
      {:error, :not_configured}
    else
      {:ok,
       %{
         base_url: base_url,
         model: model,
         api_key: merged |> get_setting(:api_key) |> normalize_string(),
         timeout_ms: integer_setting(merged, :timeout_ms, @default_timeout_ms, 1),
         max_attempts: integer_setting(merged, :max_attempts, @default_max_attempts, 1),
         base_delay_ms: integer_setting(merged, :base_delay_ms, @default_base_delay_ms, 0),
         max_delay_ms: integer_setting(merged, :max_delay_ms, @default_max_delay_ms, 0)
       }}
    end
  end

  defp strip_trailing_slash(nil), do: nil
  defp strip_trailing_slash(url), do: String.trim_trailing(url, "/")

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
