defmodule JosjobRag.Test.FakeEmbeddings do
  @moduledoc false
  # Deterministic local embeddings for Analyzer tests. Returns the local space
  # so the analyzer stores and reads vectors under a consistent provider/model.

  def embed_many(texts, opts) do
    dimensions = Keyword.get(opts, :dimensions, 1536)
    vectors = Enum.map(texts, &JosjobRag.Embeddings.Local.embed(&1, dimensions))

    {:ok, vectors, %{provider: "local", model: "hashed-bow-v1", dimensions: dimensions}}
  end
end
