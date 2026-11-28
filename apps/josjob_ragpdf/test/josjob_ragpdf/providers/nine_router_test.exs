defmodule JosjobRagpdf.Providers.NineRouterTest do
  use ExUnit.Case, async: false

  alias JosjobRagpdf.FakeHTTP
  alias JosjobRagpdf.Providers.NineRouter

  @result %{
    "skills" => [%{"name" => "Elixir", "confidence" => 0.7, "source" => "nine_router"}],
    "experience" => [],
    "education" => [],
    "extraction_confidence" => 0.6
  }

  setup do
    start_supervised!(FakeHTTP)
    :ok
  end

  describe "configuration" do
    test "returns :not_configured when base_url is missing" do
      assert {:error, :not_configured} =
               NineRouter.extract_text("Elixir developer",
                 config: config(base_url: nil),
                 http_client: FakeHTTP
               )

      assert FakeHTTP.requests() == []
    end

    test "returns :not_configured when model is missing" do
      assert {:error, :not_configured} =
               NineRouter.extract_text("Elixir developer",
                 config: config(model: "  "),
                 http_client: FakeHTTP
               )

      assert FakeHTTP.requests() == []
    end

    test "returns :no_text for blank text without calling the API" do
      assert {:error, :no_text} =
               NineRouter.extract_text("   \n ", config: config(), http_client: FakeHTTP)

      assert FakeHTTP.requests() == []
    end
  end

  describe "extract_text/2 request shape" do
    test "posts an OpenAI-compatible chat completion with auth" do
      FakeHTTP.set_responses([ok_completion(@result)])

      opts = [
        config: config(base_url: "https://router.test/v1/"),
        http_client: FakeHTTP,
        index: 1,
        total: 2,
        filename: "cv.pdf",
        known_skills: ["Elixir"]
      ]

      assert {:ok, @result, meta} = NineRouter.extract_text("Elixir developer", opts)

      assert meta == %{
               provider: "nine_router",
               model: "router-test-model",
               usage: %{"prompt_tokens" => 5, "completion_tokens" => 7}
             }

      assert [request] = FakeHTTP.requests()
      assert request.method == :post
      assert request.url == "https://router.test/v1/chat/completions"

      headers = Map.new(request.opts[:headers])
      assert headers["authorization"] == "Bearer router-secret"
      assert headers["content-type"] == "application/json"

      body = request.opts[:json]
      assert body["model"] == "router-test-model"
      assert body["temperature"] == 0
      assert body["response_format"] == %{"type" => "json_object"}

      assert [%{"role" => "system", "content" => system}, %{"role" => "user", "content" => user}] =
               body["messages"]

      assert system == JosjobRagpdf.Prompt.system()
      assert user =~ "chunk 1 of 2"
      assert user =~ "cv.pdf"
      assert user =~ "Elixir developer"
      refute Jason.encode!(body) =~ "router-secret"
    end

    test "omits the Authorization header when no key is configured" do
      FakeHTTP.set_responses([ok_completion(@result)])

      assert {:ok, _result, _meta} =
               NineRouter.extract_text("Elixir developer",
                 config: config(api_key: nil),
                 http_client: FakeHTTP
               )

      headers = Map.new(FakeHTTP.last_request().opts[:headers])
      refute Map.has_key?(headers, "authorization")
    end

    test "omits the Authorization header for a blank key" do
      FakeHTTP.set_responses([ok_completion(@result)])

      assert {:ok, _result, _meta} =
               NineRouter.extract_text("Elixir developer",
                 config: config(api_key: "  "),
                 http_client: FakeHTTP
               )

      headers = Map.new(FakeHTTP.last_request().opts[:headers])
      refute Map.has_key?(headers, "authorization")
    end
  end

  describe "response parsing" do
    test "accepts a plain JSON string content" do
      FakeHTTP.set_responses([ok_completion(@result)])

      assert {:ok, @result, meta} =
               NineRouter.extract_text("Elixir developer",
                 config: config(),
                 http_client: FakeHTTP
               )

      assert meta.provider == "nine_router"
      assert meta.usage == %{"prompt_tokens" => 5, "completion_tokens" => 7}
    end

    test "strips markdown fences around JSON" do
      fenced = "```json\n" <> Jason.encode!(@result) <> "\n```"

      FakeHTTP.set_responses([
        {:ok,
         %{
           status: 200,
           body: %{"choices" => [%{"message" => %{"content" => fenced}}]},
           headers: []
         }}
      ])

      assert {:ok, @result, _meta} =
               NineRouter.extract_text("Elixir developer",
                 config: config(),
                 http_client: FakeHTTP
               )
    end

    test "accepts content split into parts" do
      json = Jason.encode!(@result)
      {first, second} = String.split_at(json, 15)

      FakeHTTP.set_responses([
        {:ok,
         %{
           status: 200,
           body: %{
             "choices" => [
               %{"message" => %{"content" => [%{"text" => first}, %{"text" => second}]}}
             ]
           },
           headers: []
         }}
      ])

      assert {:ok, @result, _meta} =
               NineRouter.extract_text("Elixir developer",
                 config: config(),
                 http_client: FakeHTTP
               )
    end

    test "returns an invalid_response error for non-JSON content" do
      FakeHTTP.set_responses([
        {:ok,
         %{
           status: 200,
           body: %{"choices" => [%{"message" => %{"content" => "not json"}}]},
           headers: []
         }}
      ])

      assert {:error, {:invalid_response, :invalid_json}} =
               NineRouter.extract_text("Elixir developer",
                 config: config(),
                 http_client: FakeHTTP
               )
    end

    test "returns an invalid_response error for empty content" do
      FakeHTTP.set_responses([
        {:ok,
         %{
           status: 200,
           body: %{"choices" => [%{"message" => %{"content" => "  "}}]},
           headers: []
         }}
      ])

      assert {:error, {:invalid_response, :empty_completion}} =
               NineRouter.extract_text("Elixir developer",
                 config: config(),
                 http_client: FakeHTTP
               )
    end

    test "returns an invalid_response error when choices are missing" do
      FakeHTTP.set_responses([{:ok, %{status: 200, body: %{"choices" => []}, headers: []}}])

      assert {:error, {:invalid_response, :no_choices}} =
               NineRouter.extract_text("Elixir developer",
                 config: config(),
                 http_client: FakeHTTP
               )
    end
  end

  describe "failures and retries" do
    test "retries a 5xx and returns the eventual success" do
      FakeHTTP.set_responses([
        {:ok, %{status: 500, body: "boom", headers: []}},
        ok_completion(@result)
      ])

      assert {:ok, @result, _meta} =
               NineRouter.extract_text("Elixir developer",
                 config: config(max_attempts: 2),
                 http_client: FakeHTTP
               )

      assert length(FakeHTTP.requests()) == 2
    end

    test "returns the last http status after exhausting retries" do
      FakeHTTP.set_responses([
        {:ok, %{status: 502, body: "bad gateway", headers: []}},
        {:ok, %{status: 503, body: "unavailable", headers: []}}
      ])

      assert {:error, {:http_status, 503, snippet}} =
               NineRouter.extract_text("Elixir developer",
                 config: config(max_attempts: 2),
                 http_client: FakeHTTP
               )

      assert snippet =~ "unavailable"
      assert length(FakeHTTP.requests()) == 2
    end

    test "does not retry a 401 and redacts the configured key" do
      FakeHTTP.set_responses([
        {:ok, %{status: 401, body: "bad token router-secret", headers: []}}
      ])

      assert {:error, {:http_status, 401, snippet}} =
               NineRouter.extract_text("Elixir developer",
                 config: config(),
                 http_client: FakeHTTP
               )

      refute snippet =~ "router-secret"
      assert snippet =~ "[redacted]"
      assert length(FakeHTTP.requests()) == 1
    end

    test "propagates transport errors" do
      FakeHTTP.set_responses([{:error, :econnrefused}])

      assert {:error, :econnrefused} =
               NineRouter.extract_text("Elixir developer",
                 config: config(max_attempts: 1),
                 http_client: FakeHTTP
               )
    end
  end

  describe "extract_pdf/2" do
    test "returns an error instead of raising for a missing file" do
      missing = Path.join(System.tmp_dir!(), "josjob_ragpdf-missing-nine-router.pdf")

      assert {:error, _reason} =
               NineRouter.extract_pdf(missing, config: config(), http_client: FakeHTTP)

      assert FakeHTTP.requests() == []
    end
  end

  defp config(overrides \\ []) do
    Keyword.merge(
      [
        base_url: "https://router.test/v1",
        model: "router-test-model",
        api_key: "router-secret",
        timeout_ms: 1_000,
        max_attempts: 2,
        base_delay_ms: 0,
        max_delay_ms: 0
      ],
      overrides
    )
  end

  defp ok_completion(result) do
    {:ok,
     %{
       status: 200,
       body: %{
         "choices" => [%{"message" => %{"content" => Jason.encode!(result)}}],
         "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 7}
       },
       headers: [{"content-type", "application/json"}]
     }}
  end
end
