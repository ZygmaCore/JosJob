defmodule JosjobRag.Embeddings.Local do
  @moduledoc """
  Deterministic local embeddings used when Gemini is not configured or fails.

  This is a hashed bag-of-words model (feature hashing), not a neural embedding.
  It gives the pipeline a usable semantic signal:

    * identical or heavily overlapping texts score close to `1.0`
    * unrelated texts score near `0.0` (orthogonal hashed buckets)

  The output always has the configured dimensions (1536 by default) so local and
  Gemini vectors have the same shape. They are still **different spaces** and are
  never compared with each other. `model/0` identifies the algorithm; bump it
  whenever the hashing scheme changes.
  """

  alias JosjobRag.{Cosine, Text}

  @model "hashed-bow-v1"
  @hashes_per_token 3
  @token_weight 1.0
  @text_weight 0.25
  @default_dimensions 1536

  @doc "Stable provider name stored next to every vector."
  def name, do: "local"

  @doc "Stable algorithm name; bump when the hashing scheme changes."
  def model, do: @model

  @doc "The local provider is always available."
  def configured?, do: true

  @doc "Embed many texts deterministically."
  @spec embed_many([String.t()], keyword()) :: {:ok, [[float()]]} | {:error, term()}
  def embed_many(texts, opts \\ []) when is_list(texts) do
    dimensions = Keyword.get(opts, :dimensions, default_dimensions())
    {:ok, Enum.map(texts, &embed(&1, dimensions))}
  end

  @doc """
  Embed one text into a unit-length vector of `dimensions` floats.

  Every non-empty text contributes at least one hashed feature, so the returned
  vector is never all zeros (which would make cosine distance undefined).
  """
  @spec embed(term(), pos_integer()) :: [float()]
  def embed(text, dimensions \\ nil) do
    dimensions = dimensions || default_dimensions()

    features =
      text
      |> Text.tokens()
      |> Enum.flat_map(&token_features(&1, @token_weight, dimensions))

    text_feature =
      case Text.normalize(text) do
        "" -> []
        normalized -> hashed_feature("__text__:" <> normalized, @text_weight, dimensions)
      end

    (features ++ text_feature)
    |> Enum.reduce(%{}, fn {index, value}, acc ->
      Map.update(acc, index, value, &(&1 + value))
    end)
    |> vector_from_map(dimensions)
    |> Cosine.normalize()
  end

  defp token_features(token, weight, dimensions) do
    Enum.flat_map(0..(@hashes_per_token - 1), fn salt ->
      hashed_feature(token, weight, dimensions, salt)
    end)
  end

  defp hashed_feature(feature, weight, dimensions, salt \\ 0) do
    <<index::unsigned-32, sign_byte, _rest::binary>> =
      :crypto.hash(:sha256, [feature, ":", Integer.to_string(salt)])

    index = rem(index, dimensions)
    sign = if rem(sign_byte, 2) == 0, do: 1.0, else: -1.0
    [{index, sign * weight}]
  end

  defp vector_from_map(map, dimensions) do
    Enum.map(0..(dimensions - 1), &Map.get(map, &1, 0.0))
  end

  defp default_dimensions do
    Application.get_env(:josjob_rag, :embeddings, [])[:dimensions] || @default_dimensions
  end
end
