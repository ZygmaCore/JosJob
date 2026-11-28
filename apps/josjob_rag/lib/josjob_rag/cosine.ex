defmodule JosjobRag.Cosine do
  @moduledoc """
  Cosine similarity for embedding vectors.

  Embeddings arrive from Gemini or from the deterministic local fallback, so the
  functions here are defensive: `nil`, empty, mismatched-length, or zero vectors
  return `0.0` instead of raising. That keeps a single bad vector from breaking
  a whole ranking response.
  """

  @doc """
  Cosine similarity in `[-1.0, 1.0]`.

  Returns `0.0` when either vector is missing, empty, of a different length, or
  has zero magnitude.
  """
  @spec similarity([number()] | nil, [number()] | nil) :: float()
  def similarity(a, b) when is_list(a) and is_list(b) do
    if length(a) == length(b) and a != [] do
      {dot, norm_a, norm_b} =
        Enum.zip(a, b)
        |> Enum.reduce({0.0, 0.0, 0.0}, fn {x, y}, {dot, na, nb} ->
          {dot + x * y, na + x * x, nb + y * y}
        end)

      denominator = :math.sqrt(norm_a) * :math.sqrt(norm_b)
      if denominator == 0.0, do: 0.0, else: clamp(dot / denominator)
    else
      0.0
    end
  end

  def similarity(_a, _b), do: 0.0

  @doc "L2-normalize a vector. Returns the input when it is empty or zero."
  @spec normalize([number()]) :: [float()]
  def normalize(vector) when is_list(vector) do
    norm = :math.sqrt(Enum.reduce(vector, 0.0, fn value, acc -> acc + value * value end))

    if norm == 0.0 do
      Enum.map(vector, &(&1 * 1.0))
    else
      Enum.map(vector, &(&1 / norm))
    end
  end

  def normalize(_vector), do: []

  @doc """
  Map cosine similarity to `[0.0, 1.0]` for scoring.

  Negative similarities are clamped to `0.0` (unrelated on the opposite side of
  the embedding space is not useful signal) and perfect similarity maps to
  `1.0`.
  """
  @spec similarity_to_score([number()] | nil, [number()] | nil) :: float()
  def similarity_to_score(a, b) do
    a |> similarity(b) |> max(0.0) |> min(1.0)
  end

  defp clamp(value) when value > 1.0, do: 1.0
  defp clamp(value) when value < -1.0, do: -1.0
  defp clamp(value), do: value * 1.0
end
