defmodule JosjobRagpdf.AITest do
  use ExUnit.Case, async: false

  alias JosjobRagpdf.AI
  alias JosjobRagpdf.FakeHTTP

  @result %{
    "skills" => [%{"name" => "Elixir", "confidence" => 0.8, "source" => "gemini"}],
    "experience" => [],
    "education" => [],
    "extraction_confidence" => 0.8
  }

  setup do
    start_supervised!(FakeHTTP)
    tmp_dir = tmp_dir()
    %{tmp_dir: tmp_dir}
  end

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "josjob_ragpdf-ai-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  describe "provider order" do
    test "tries providers in the given order and stops at the first success" do
      FakeHTTP.set_responses([gemini_ok(@result)])

      assert {:ok, result, meta} =
               AI.extract_text("Elixir developer",
                 providers: [:gemini, :keyword],
                 http_client: FakeHTTP,
                 config: gemini_config(),
                 known_skills: ["Elixir"]
               )

      assert result["skills"] == @result["skills"]

      assert meta == %{
               provider: "gemini",
               model: "gemini-ai-test",
               usage: %{"promptTokenCount" => 3, "candidatesTokenCount" => 4}
             }

      assert length(FakeHTTP.requests()) == 1
    end

    test "falls back to the next provider when the first is not configured" do
      assert {:ok, result, meta} =
               AI.extract_text("Elixir developer",
                 providers: [:gemini, :keyword],
                 http_client: FakeHTTP,
                 config: [api_key: nil],
                 known_skills: ["Elixir"]
               )

      assert [%{"name" => "Elixir", "source" => "keyword"}] = result["skills"]
      assert meta == %{provider: "keyword", model: nil, usage: nil}
      assert FakeHTTP.requests() == []
    end

    test "falls back when a provider returns an HTTP error" do
      FakeHTTP.set_responses([{:ok, %{status: 500, body: "boom", headers: []}}])

      assert {:ok, _result, meta} =
               AI.extract_text("Elixir developer",
                 providers: [:gemini, :keyword],
                 http_client: FakeHTTP,
                 config: gemini_config(max_attempts: 1),
                 known_skills: ["Elixir"]
               )

      assert meta.provider == "keyword"
      assert length(FakeHTTP.requests()) == 1
    end

    test "filters unknown providers and accepts known string names" do
      assert {:error, {:all_providers_failed, [{:gemini, :not_configured}]}} =
               AI.extract_text("Elixir developer",
                 providers: [:not_a_provider, "gemini", "bogus", :not_a_provider],
                 http_client: FakeHTTP,
                 config: [api_key: nil]
               )

      assert FakeHTTP.requests() == []
    end

    test "an empty provider list fails with no attempts" do
      assert {:error, {:all_providers_failed, []}} =
               AI.extract_text("Elixir developer", providers: [])
    end

    test "reads the order from application env when opts are absent" do
      previous = Application.get_env(:josjob_ragpdf, :provider_order, [])

      on_exit(fn ->
        Application.put_env(:josjob_ragpdf, :provider_order, previous)
      end)

      Application.put_env(:josjob_ragpdf, :provider_order, [:bogus, :keyword])

      assert {:ok, _result, %{provider: "keyword"}} =
               AI.extract_text("Elixir developer", known_skills: ["Elixir"])
    end
  end

  describe "failures" do
    test "returns every attempt in order when all providers fail" do
      assert {:error, {:all_providers_failed, attempts}} =
               AI.extract_text("   ",
                 providers: [:gemini, :nine_router, :keyword],
                 http_client: FakeHTTP,
                 config: [api_key: nil, base_url: nil, model: nil]
               )

      assert Enum.map(attempts, &elem(&1, 0)) == [:gemini, :nine_router, :keyword]
      assert {:gemini, :not_configured} = Enum.at(attempts, 0)
      # NineRouter validates the text before its config, so blank text is :no_text.
      assert {:nine_router, :no_text} = Enum.at(attempts, 1)
      assert {:keyword, :no_text} = Enum.at(attempts, 2)
    end

    test "reports nine_router as not configured for non-blank text" do
      assert {:error, {:all_providers_failed, attempts}} =
               AI.extract_text("Elixir developer",
                 providers: [:gemini, :nine_router],
                 http_client: FakeHTTP,
                 config: [api_key: nil, base_url: nil, model: nil]
               )

      assert [{:gemini, :not_configured}, {:nine_router, :not_configured}] = attempts
    end

    test "keeps error details free of secrets" do
      FakeHTTP.set_responses([
        {:ok, %{status: 500, body: "provider said: bad key super-secret", headers: []}}
      ])

      assert {:error, {:all_providers_failed, attempts}} =
               AI.extract_text("Elixir developer",
                 providers: [:gemini],
                 http_client: FakeHTTP,
                 config: gemini_config(api_key: "super-secret", max_attempts: 1)
               )

      assert [{:gemini, {:http_status, 500, snippet}}] = attempts
      refute inspect(snippet) =~ "super-secret"
    end
  end

  describe "result normalization" do
    test "normalizes provider output before returning it" do
      raw = %{
        "skills" => [%{"name" => "  Elixir  ", "confidence" => 2.0, "junk" => true}],
        "experience" => [],
        "education" => [],
        "extraction_confidence" => 5,
        "unknown_field" => "drop me"
      }

      FakeHTTP.set_responses([gemini_ok(raw)])

      assert {:ok, result, %{provider: "gemini"}} =
               AI.extract_text("Elixir developer",
                 providers: [:gemini],
                 http_client: FakeHTTP,
                 config: gemini_config()
               )

      assert [skill] = result["skills"]
      assert skill["name"] == "Elixir"
      assert skill["confidence"] == 1.0
      assert result["extraction_confidence"] == 1.0
      refute Map.has_key?(result, "unknown_field")
      refute Map.has_key?(skill, "junk")
    end
  end

  describe "extract_chunk/2" do
    test "sends the PDF path's bytes through the provider chain", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "cv.pdf")
      File.write!(path, "%PDF-1.4\nfake\n")

      FakeHTTP.set_responses([gemini_ok(@result)])

      assert {:ok, _result, %{provider: "gemini"}} =
               AI.extract_chunk(path,
                 providers: [:gemini],
                 http_client: FakeHTTP,
                 config: gemini_config(),
                 index: 1,
                 total: 2,
                 filename: "cv.pdf"
               )

      body = FakeHTTP.last_request().opts[:json]

      assert [%{"parts" => [%{"text" => prompt}, %{"inline_data" => inline}]}] =
               body["contents"]

      assert prompt =~ "chunk 1 of 2"
      assert inline["mime_type"] == "application/pdf"
      assert Base.decode64!(inline["data"]) == "%PDF-1.4\nfake\n"
    end
  end

  defp gemini_config(overrides \\ []) do
    Keyword.merge(
      [
        base_url: "https://gemini.test",
        model: "gemini-ai-test",
        api_key: "gemini-key",
        timeout_ms: 1_000,
        max_attempts: 1,
        base_delay_ms: 0,
        max_delay_ms: 0
      ],
      overrides
    )
  end

  defp gemini_ok(result) do
    body = %{
      "candidates" => [%{"content" => %{"parts" => [%{"text" => Jason.encode!(result)}]}}],
      "usageMetadata" => %{"promptTokenCount" => 3, "candidatesTokenCount" => 4}
    }

    {:ok,
     %{
       status: 200,
       body: Jason.encode!(body),
       headers: [{"content-type", "application/json"}]
     }}
  end
end
