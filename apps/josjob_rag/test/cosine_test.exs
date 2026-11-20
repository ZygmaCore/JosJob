defmodule JosjobRag.CosineTest do
  use ExUnit.Case, async: true

  alias JosjobRag.Cosine

  describe "similarity/2" do
    test "identical vectors score 1.0" do
      assert Cosine.similarity([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]) == 1.0
    end

    test "orthogonal vectors score 0.0" do
      assert Cosine.similarity([1.0, 0.0], [0.0, 1.0]) == 0.0
    end

    test "opposite vectors score -1.0" do
      assert Cosine.similarity([1.0, 0.0], [-1.0, 0.0]) == -1.0
    end

    test "scale does not matter" do
      assert_in_delta Cosine.similarity([1.0, 1.0], [10.0, 10.0]), 1.0, 1.0e-9
    end

    test "mismatched lengths, empty vectors, and non-lists return 0.0" do
      assert Cosine.similarity([1.0, 2.0], [1.0]) == 0.0
      assert Cosine.similarity([], []) == 0.0
      assert Cosine.similarity(nil, [1.0]) == 0.0
      assert Cosine.similarity([1.0], nil) == 0.0
      assert Cosine.similarity("nope", [1.0]) == 0.0
    end

    test "a zero vector returns 0.0 instead of dividing by zero" do
      assert Cosine.similarity([0.0, 0.0], [1.0, 1.0]) == 0.0
    end
  end

  describe "normalize/1" do
    test "produces a unit-length vector" do
      vector = Cosine.normalize([3.0, 4.0])
      assert_in_delta :math.sqrt(Enum.sum(Enum.map(vector, &(&1 * &1)))), 1.0, 1.0e-9
    end

    test "keeps a zero vector as floats" do
      assert Cosine.normalize([0.0, 0.0]) == [0.0, 0.0]
    end
  end

  describe "similarity_to_score/2" do
    test "clamps negative similarity to zero" do
      assert Cosine.similarity_to_score([1.0, 0.0], [-1.0, 0.0]) == 0.0
    end

    test "keeps positive similarity" do
      assert Cosine.similarity_to_score([1.0, 0.0], [1.0, 0.0]) == 1.0
    end
  end
end
