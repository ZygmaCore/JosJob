defmodule JosjobRag.VectorStoreDbTest do
  # Exercises the real pgvector SQL: inserts, upserts, space isolation, and the
  # cosine nearest-neighbour query. The pure helpers are covered in
  # `vector_store_test.exs`; this file needs PostgreSQL with the `vector`
  # extension and is rolled back by the sandbox.
  use Josjob.DataCase, async: false

  alias JosjobRag.VectorStore

  @dims 1536
  @space [provider: "local", model: "hashed-bow-v1"]

  # One-hot vectors make cosine similarity easy to reason about: identical
  # indices score 1.0, different indices score 0.0.
  defp unit(index) do
    List.duplicate(0.0, @dims) |> List.replace_at(index, 1.0)
  end

  defp put!(owner_type, owner_id, text, vector, opts \\ []) do
    assert {:ok, id} =
             VectorStore.put(owner_type, owner_id, text, vector, Keyword.merge(@space, opts))

    id
  end

  test "put/get round-trips the vector, hash, and space" do
    vector = unit(0)
    id = put!(:job, "job-1", "Elixir backend", vector)

    assert {:ok, row} = VectorStore.get(:job, "job-1")
    assert row.id == id
    assert row.owner_type == "job"
    assert row.owner_id == "job-1"
    assert row.provider == "local"
    assert row.model == "hashed-bow-v1"
    assert row.dimensions == @dims
    assert row.content_hash == VectorStore.content_hash("Elixir backend")
    assert row.source_text == "Elixir backend"
    assert row.embedding == vector
  end

  test "put/5 upserts on the same owner and space" do
    put!(:job, "job-1", "first text", unit(0))
    put!(:job, "job-1", "second text", unit(1))

    assert {:ok, row} = VectorStore.get(:job, "job-1")
    assert row.source_text == "second text"
    assert row.content_hash == VectorStore.content_hash("second text")
    assert row.embedding == unit(1)
    assert {:ok, 1} = VectorStore.count(:job)
  end

  test "the same owner can live in several spaces without collisions" do
    put!(:job, "job-1", "local text", unit(0))
    put!(:job, "job-1", "gemini text", unit(1), provider: "gemini", model: "gemini-embedding-2")

    assert {:ok, 2} = VectorStore.count(:job)

    assert {:ok, local} = VectorStore.get(:job, "job-1", provider: "local")
    assert local.embedding == unit(0)

    assert {:ok, gemini} = VectorStore.get(:job, "job-1", provider: "gemini")
    assert gemini.embedding == unit(1)

    assert {:ok, spaces} = VectorStore.spaces(:job)
    assert length(spaces) == 2
    assert Enum.map(spaces, & &1.provider) |> Enum.sort() == ["gemini", "local"]

    assert {:ok, dominant} = VectorStore.dominant_space(:job)
    assert dominant.provider in ["gemini", "local"]
    assert dominant.count == 1
  end

  test "hashes/4 and vectors/4 only return the requested space" do
    put!(:job, "job-1", "first", unit(0))
    put!(:job, "job-2", "second", unit(1))
    put!(:job, "job-3", "gemini", unit(2), provider: "gemini", model: "gemini-embedding-2")

    assert {:ok, hashes} =
             VectorStore.hashes(:job, ["job-1", "job-2", "job-3"], "local", "hashed-bow-v1")

    assert map_size(hashes) == 2
    assert hashes["job-1"] == VectorStore.content_hash("first")
    refute Map.has_key?(hashes, "job-3")

    assert {:ok, vectors} =
             VectorStore.vectors(:job, ["job-1", "job-2"], "local", "hashed-bow-v1")

    assert vectors == %{"job-1" => unit(0), "job-2" => unit(1)}

    assert {:ok, %{}} = VectorStore.hashes(:job, [], "local", "hashed-bow-v1")
    assert {:ok, %{}} = VectorStore.vectors(:job, [], "local", "hashed-bow-v1")
  end

  test "nearest/3 orders by cosine similarity and filters by owner type and space" do
    put!(:job, "exact", "exact", unit(0))
    put!(:job, "orthogonal", "orthogonal", unit(1))
    put!(:job, "gemini-only", "gemini", unit(0), provider: "gemini", model: "gemini-embedding-2")
    put!(:course, "course-1", "course", unit(0))

    assert {:ok, results} =
             VectorStore.nearest(:job, unit(0), @space ++ [limit: 10, min_similarity: 0.5])

    assert [exact] = results
    assert exact.owner_id == "exact"
    assert_in_delta exact.similarity, 1.0, 1.0e-6

    assert {:ok, all} =
             VectorStore.nearest(:job, unit(0), provider: "local", model: "hashed-bow-v1")

    assert Enum.map(all, & &1.owner_id) == ["exact", "orthogonal"]
    assert_in_delta List.last(all).similarity, 0.0, 1.0e-6
  end

  test "delete removes one owner, delete_space removes one space only" do
    put!(:job, "job-1", "first", unit(0))
    put!(:job, "job-1", "gemini", unit(1), provider: "gemini", model: "gemini-embedding-2")
    put!(:job, "job-2", "second", unit(1))

    assert {:ok, 2} = VectorStore.delete(:job, "job-1")
    assert {:ok, %{}} = VectorStore.hashes(:job, ["job-1"], "local", "hashed-bow-v1")
    assert {:ok, 1} = VectorStore.count(:job)

    put!(:job, "job-3", "third", unit(2))

    assert {:ok, 2} = VectorStore.delete_space(:job, "local", "hashed-bow-v1")
    assert {:ok, 0} = VectorStore.count(:job)
  end
end
