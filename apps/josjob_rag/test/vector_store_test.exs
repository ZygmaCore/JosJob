defmodule JosjobRag.VectorStoreTest do
  use ExUnit.Case, async: true

  alias JosjobRag.VectorStore

  describe "format_vector/1" do
    test "formats floats the way pgvector expects" do
      assert VectorStore.format_vector([1.0, 0.5, -0.25]) == "[1.0,0.5,-0.25]"
    end

    test "formats integers without a decimal point" do
      assert VectorStore.format_vector([1, 2, -3]) == "[1,2,-3]"
    end
  end

  describe "parse_vector/1" do
    test "parses pgvector text output" do
      assert VectorStore.parse_vector("[0.1,0.2,-1.5]") == [0.1, 0.2, -1.5]
    end

    test "handles an empty vector and nil" do
      assert VectorStore.parse_vector("[]") == []
      assert VectorStore.parse_vector(nil) == []
    end

    test "accepts an existing list and converts integers" do
      assert VectorStore.parse_vector([1, 2]) == [1.0, 2.0]
    end

    test "round-trips through format_vector/1" do
      vector = [1.0, 0.0, -0.5]
      assert vector |> VectorStore.format_vector() |> VectorStore.parse_vector() == vector
    end
  end

  describe "content_hash/1" do
    test "is deterministic and text-sensitive" do
      hash = VectorStore.content_hash("same text")
      assert VectorStore.content_hash("same text") == hash
      refute VectorStore.content_hash("other text") == hash
      assert is_binary(hash)
    end

    test "converts non-binary input without raising" do
      assert VectorStore.content_hash(nil) == VectorStore.content_hash("")
    end
  end

  describe "validation before touching the database" do
    test "rejects unknown owner types" do
      assert VectorStore.put(:unknown, "id", "text", [1.0]) ==
               {:error, {:invalid_owner_type, "unknown"}}

      assert VectorStore.delete(:unknown, "id") ==
               {:error, {:invalid_owner_type, "unknown"}}
    end

    test "rejects blank owner ids" do
      assert VectorStore.delete(:job, "   ") == {:error, :invalid_owner_id}
      assert VectorStore.delete(:job, nil) == {:error, :invalid_owner_id}
    end

    test "rejects vectors with the wrong dimensions" do
      assert VectorStore.put(:job, "job-1", "text", [1.0, 2.0]) ==
               {:error, {:invalid_dimensions, 2}}
    end
  end
end
