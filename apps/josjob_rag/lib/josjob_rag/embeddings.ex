defmodule JosjobRag.Embeddings do
  @moduledoc """
  Embedding provider dispatch and the embedding "space" used by the vector store.

  Two providers exist:

    * `JosjobRag.Embeddings.Gemini` — real embeddings through the Gemini API
      (`gemini-embedding-2`, 1536 dimensions, `SEMANTIC_SIMILARITY`).
    * `JosjobRag.Embeddings.Local` — a deterministic hashed bag-of-words fallback
      so the whole pipeline keeps working without an API key or network access.

  Vectors from different providers/models are **not comparable**. Every stored
  vector carries its provider, model, and dimensions, and the analyzer ranks
  only inside one space. `embed_many/2` therefore returns the space that actually
  produced the vectors, which may be `local` after a Gemini failure.

  Configuration (`config :josjob_rag, :embeddings`):

      provider: :auto | :gemini | :local   # :auto -> Gemini when a key exists
      model: "gemini-embedding-2"
      dimensions: 1536
      api_key: "..."
      base_url: "https://generativelanguage.googleapis.com"
  """

  require Logger

  alias JosjobRag.Embeddings.{Gemini, Local}

  @type vector :: [float()]
  @type space :: %{provider: String.t(), model: String.t(), dimensions: pos_integer()}

  @default_dimensions 1536
  @default_model "gemini-embedding-2"

  @doc "Raw embeddings configuration."
  def config, do: Application.get_env(:josjob_rag, :embeddings, [])

  @doc "Embedding dimensions used for every stored vector."
  def dimensions, do: config()[:dimensions] || @default_dimensions

  @doc "Default Gemini embedding model."
  def model, do: config()[:model] || @default_model

  @doc """
  Provider module selected by configuration.

  `:gemini` still falls back to `Local` when no API key is configured.
  """
  def configured_provider do
    case config()[:provider] do
      :local -> Local
      :gemini -> if Gemini.configured?(), do: Gemini, else: Local
      _auto -> if Gemini.configured?(), do: Gemini, else: Local
    end
  end

  @doc "The space the configured provider would write to."
  def configured_space do
    module = configured_provider()
    %{provider: module.name(), model: module.model(), dimensions: dimensions()}
  end

  @doc "Resolve a provider string (`\"gemini\"` / `\"local\"`) to a module."
  def module_for("gemini"), do: Gemini
  def module_for(:gemini), do: Gemini
  def module_for("local"), do: Local
  def module_for(:local), do: Local
  def module_for(Gemini), do: Gemini
  def module_for(Local), do: Local
  def module_for(_other), do: configured_provider()

  @doc """
  Embed one text.

  Returns `{:ok, vector, space}` or `{:error, reason}`. Gemini failures fall back
  to the deterministic local embedding unless `fallback: false` is passed.
  """
  @spec embed_one(term(), keyword()) :: {:ok, vector(), space()} | {:error, term()}
  def embed_one(text, opts \\ []) do
    with {:ok, [vector], space} <- embed_many([text], opts) do
      {:ok, vector, space}
    end
  end

  @doc """
  Embed a list of texts.

  Returns `{:ok, vectors, space}` where `space` is the provider/model that
  actually produced the vectors. An empty input returns an empty list in the
  configured space.
  """
  @spec embed_many([term()], keyword()) :: {:ok, [vector()], space()} | {:error, term()}
  def embed_many(texts, opts \\ [])

  def embed_many([], opts) do
    module = module_for(Keyword.get(opts, :provider, configured_provider()))
    {:ok, [], space(module)}
  end

  def embed_many(texts, opts) when is_list(texts) do
    texts = Enum.map(texts, &normalize_text/1)
    module = Keyword.get(opts, :provider, configured_provider())
    module = module_for(module)

    case module.embed_many(texts, opts) do
      {:ok, vectors} ->
        with :ok <- validate_vectors(vectors, length(texts)) do
          {:ok, vectors, space(module)}
        end

      {:error, reason} when module != Local ->
        if Keyword.get(opts, :fallback, true) do
          Logger.warning(
            "Gemini embeddings failed (#{inspect(reason)}); using deterministic local embeddings"
          )

          with {:ok, vectors} <- Local.embed_many(texts, opts) do
            {:ok, vectors, space(Local)}
          end
        else
          {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Space descriptor for a provider module (dimensions included)."
  @spec space(module()) :: space()
  def space(module) do
    %{provider: module.name(), model: module.model(), dimensions: dimensions()}
  end

  @doc "Validate an embedding vector: non-empty numbers of the configured size."
  def valid_vector?(vector) when is_list(vector) do
    length(vector) == dimensions() and Enum.all?(vector, &is_number/1)
  end

  def valid_vector?(_vector), do: false

  @doc """
  Normalize raw provider output into `[float()]` and validate dimensions.

  Exposed for tests and for callers that receive vectors from JSON.
  """
  def cast_vector(vector) when is_list(vector) do
    if Enum.all?(vector, &is_number/1) and vector != [] do
      {:ok, Enum.map(vector, &(&1 * 1.0))}
    else
      {:error, :invalid_vector}
    end
  end

  def cast_vector(_vector), do: {:error, :invalid_vector}

  defp validate_vectors(vectors, expected_count) do
    cond do
      length(vectors) != expected_count ->
        {:error, :embedding_count_mismatch}

      not Enum.all?(vectors, &valid_vector?/1) ->
        {:error, {:invalid_dimensions, dimensions()}}

      true ->
        :ok
    end
  end

  defp normalize_text(text) when is_binary(text), do: text

  defp normalize_text(text) when is_list(text) do
    text |> List.to_string() |> normalize_text()
  rescue
    _ -> ""
  end

  defp normalize_text(_text), do: ""
end
