defmodule JosjobRagpdf.AI do
  @moduledoc """
  Provider chain with fallback and result normalization.

  Providers are tried in order. The order comes from `opts[:providers]` or the
  `:provider_order` application env, filtered against the fixed allowlist
  below. Unknown entries are dropped — user input is never converted to atoms.

  On success the provider result is normalized with `JosjobRagpdf.Result.normalize/1`
  and returned with `%{provider: name, model: model, usage: usage}`.
  """

  @allowlist [:gemini, :nine_router, :keyword]

  @provider_modules %{
    gemini: JosjobRagpdf.Providers.Gemini,
    nine_router: JosjobRagpdf.Providers.NineRouter,
    keyword: JosjobRagpdf.Providers.Keyword
  }

  # Only used to accept provider names that already arrived as strings. This is
  # a fixed map, never `String.to_atom/1`.
  @provider_names %{
    "gemini" => :gemini,
    "nine_router" => :nine_router,
    "keyword" => :keyword
  }

  @type meta :: %{provider: String.t(), model: String.t() | nil, usage: map() | nil}

  @doc "Extract CV data from a PDF file, trying providers in order."
  @spec extract_chunk(String.t(), keyword()) :: {:ok, map(), meta()} | {:error, term()}
  def extract_chunk(path, opts \\ []) when is_binary(path) do
    run(:extract_pdf, path, opts)
  end

  @doc "Extract CV data from plain text, trying providers in order."
  @spec extract_text(String.t(), keyword()) :: {:ok, map(), meta()} | {:error, term()}
  def extract_text(text, opts \\ []) when is_binary(text) do
    run(:extract_text, text, opts)
  end

  @doc "Provider modules keyed by their allowlisted atom."
  @spec providers() :: %{atom() => module()}
  def providers, do: @provider_modules

  @doc "Allowed provider atoms."
  @spec allowlist() :: [atom()]
  def allowlist, do: @allowlist

  defp run(callback, input, opts) do
    providers = provider_order(opts)

    {result, attempts} =
      Enum.reduce_while(providers, {nil, []}, fn provider, {_result, attempts} ->
        case call_provider(provider, callback, input, opts) do
          {:ok, result, meta} when is_map(result) ->
            {:halt, {{:ok, normalize(result), normalize_meta(meta, provider)}, attempts}}

          {:ok, _result, _meta} ->
            {:cont, {nil, [{provider, :invalid_result} | attempts]}}

          {:error, reason} ->
            {:cont, {nil, [{provider, reason} | attempts]}}
        end
      end)

    case result do
      {:ok, normalized, meta} -> {:ok, normalized, meta}
      nil -> {:error, {:all_providers_failed, Enum.reverse(attempts)}}
    end
  end

  defp call_provider(provider, callback, input, opts) do
    module = Map.fetch!(@provider_modules, provider)

    try do
      apply(module, callback, [input, opts])
    rescue
      exception ->
        # Never leak provider messages: they may contain URLs, keys, or text.
        {:error, {:provider_error, exception.__struct__}}
    catch
      kind, _reason ->
        {:error, {:provider_error, kind}}
    end
  end

  defp normalize(result) do
    JosjobRagpdf.Result.normalize(result)
  rescue
    _exception -> result
  end

  defp normalize_meta(meta, provider) when is_map(meta) do
    %{
      provider: provider_string(meta_value(meta, :provider), provider),
      model: model_value(meta_value(meta, :model)),
      usage: usage_value(meta_value(meta, :usage))
    }
  end

  defp normalize_meta(_meta, provider) do
    %{provider: Atom.to_string(provider), model: nil, usage: nil}
  end

  defp provider_string(value, provider) when is_binary(value) do
    case String.trim(value) do
      "" -> fallback_provider_name(provider)
      trimmed -> trimmed
    end
  end

  defp provider_string(value, _provider) when is_atom(value) and not is_nil(value) do
    Atom.to_string(value)
  end

  defp provider_string(_value, provider), do: fallback_provider_name(provider)

  defp fallback_provider_name(provider), do: Atom.to_string(provider)

  defp model_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp model_value(_value), do: nil

  defp usage_value(value) when is_map(value), do: value
  defp usage_value(_value), do: nil

  defp meta_value(meta, key) do
    Map.get(meta, key) || Map.get(meta, Atom.to_string(key))
  end

  defp provider_order(opts) do
    configured =
      case Keyword.get(opts, :providers) do
        nil -> Application.get_env(:josjob_ragpdf, :provider_order, @allowlist)
        providers -> providers
      end

    normalize_order(configured)
  end

  defp normalize_order(providers) when is_list(providers) do
    providers
    |> Enum.map(&normalize_provider/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_order(_providers), do: []

  defp normalize_provider(provider) when is_atom(provider) do
    if provider in @allowlist, do: provider
  end

  defp normalize_provider(provider) when is_binary(provider) do
    Map.get(@provider_names, String.trim(provider))
  end

  defp normalize_provider(_provider), do: nil
end
