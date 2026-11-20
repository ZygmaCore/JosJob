defmodule JosjobRag.EmbeddingsTest do
  # Gemini tests mutate the application environment, so keep this file serial.
  use ExUnit.Case, async: false

  alias JosjobRag.{Cosine, Embeddings}
  alias JosjobRag.Embeddings.{Gemini, Local}

  @dimensions 1536

  describe "local fallback embeddings" do
    test "are deterministic, unit length, and use the configured dimensions" do
      first = Local.embed("Elixir Phoenix backend engineer")
      second = Local.embed("Elixir Phoenix backend engineer")

      assert first == second
      assert length(first) == @dimensions
      assert Cosine.similarity(first, first) == 1.0
    end

    test "put related texts closer than unrelated ones" do
      query = Local.embed("Elixir Phoenix backend API developer")
      related = Local.embed("Senior backend engineer, Elixir and Phoenix APIs")
      unrelated = Local.embed("Graphic designer, Adobe Illustrator and brand identity")

      assert Cosine.similarity(query, related) > Cosine.similarity(query, unrelated)
    end

    test "an empty text still returns a full-size vector" do
      assert length(Local.embed("")) == @dimensions
    end
  end

  describe "embed_many/2" do
    test "returns vectors together with the space that produced them" do
      assert {:ok, vectors, space} =
               Embeddings.embed_many(["one", "two"], provider: Local)

      assert length(vectors) == 2
      assert Enum.all?(vectors, &(length(&1) == @dimensions))

      assert space == %{provider: "local", model: "hashed-bow-v1", dimensions: @dimensions}
    end

    test "an empty input returns the requested space" do
      assert {:ok, [], space} = Embeddings.embed_many([], provider: Local)
      assert space.provider == "local"
      assert space.dimensions == @dimensions
    end

    test "embed_one/2 returns a single vector" do
      assert {:ok, vector, %{provider: "local"}} = Embeddings.embed_one("hello")
      assert length(vector) == @dimensions
    end

    test "cast_vector/1 converts numbers to floats and rejects bad input" do
      assert {:ok, [1.0, 2.0]} = Embeddings.cast_vector([1, 2.0])
      assert {:error, :invalid_vector} = Embeddings.cast_vector([])
      assert {:error, :invalid_vector} = Embeddings.cast_vector(["x"])
      assert {:error, :invalid_vector} = Embeddings.cast_vector(nil)
    end
  end

  describe "Gemini provider" do
    @api_key "test-key"

    test "a single text uses embedContent with the expected payload" do
      vector = List.duplicate(0.25, @dimensions)
      parent = self()

      http = fn url, opts ->
        send(parent, {:request, url, opts})

        {:ok,
         %{
           status: 200,
           body: %{"embedding" => %{"values" => vector}}
         }}
      end

      assert {:ok, [result], space} =
               Embeddings.embed_many(["Backend engineer"],
                 provider: Gemini,
                 api_key: @api_key,
                 http_client: http
               )

      assert result == vector
      assert space == %{provider: "gemini", model: "gemini-embedding-2", dimensions: @dimensions}

      assert_received {:request, url, opts}
      assert url =~ ":embedContent"
      assert {"x-goog-api-key", "test-key"} in opts[:headers]

      assert opts[:json]["taskType"] == "SEMANTIC_SIMILARITY"
      assert opts[:json]["outputDimensionality"] == @dimensions
      assert opts[:json]["content"]["parts"] == [%{"text" => "Backend engineer"}]
    end

    test "several texts use batchEmbedContents and keep the order" do
      first = List.duplicate(0.1, @dimensions)
      second = List.duplicate(0.2, @dimensions)

      http = fn _url, opts ->
        assert opts[:json]["requests"] |> length() == 2

        {:ok,
         %{
           status: 200,
           body: %{
             "embeddings" => [%{"values" => first}, %{"values" => second}]
           }
         }}
      end

      assert {:ok, vectors, space} =
               Embeddings.embed_many(["one", "two"],
                 provider: Gemini,
                 api_key: @api_key,
                 http_client: http
               )

      assert vectors == [first, second]
      assert space.provider == "gemini"
    end

    test "maps HTTP errors to a tagged tuple" do
      http = fn _url, _opts ->
        {:ok, %{status: 429, body: %{"error" => %{"message" => "quota exceeded"}}}}
      end

      assert {:error, {:gemini_http_error, 429, "quota exceeded"}} =
               Embeddings.embed_many(["one"],
                 provider: Gemini,
                 api_key: @api_key,
                 http_client: http,
                 fallback: false
               )
    end

    test "falls back to local embeddings after a transport error" do
      http = fn _url, _opts -> {:error, :timeout} end

      assert {:ok, [vector], space} =
               Embeddings.embed_many(["one"],
                 provider: Gemini,
                 api_key: @api_key,
                 http_client: http
               )

      assert length(vector) == @dimensions
      assert space.provider == "local"
    end

    test "does not fall back when fallback: false is passed" do
      http = fn _url, _opts -> {:error, :timeout} end

      assert {:error, {:gemini_transport_error, :timeout}} =
               Embeddings.embed_many(["one"],
                 provider: Gemini,
                 api_key: @api_key,
                 http_client: http,
                 fallback: false
               )
    end

    test "rejects vectors with the wrong dimensions" do
      http = fn _url, _opts ->
        {:ok, %{status: 200, body: %{"embedding" => %{"values" => [0.1, 0.2]}}}}
      end

      assert {:error, {:invalid_dimensions, @dimensions}} =
               Embeddings.embed_many(["one"],
                 provider: Gemini,
                 api_key: @api_key,
                 http_client: http
               )
    end
  end
end
