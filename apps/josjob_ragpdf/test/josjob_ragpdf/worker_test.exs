defmodule JosjobRagpdf.WorkerTest do
  use ExUnit.Case, async: false

  alias JosjobRagpdf.{FakeAI, FakePDF, Job, Jobs, Temp, Worker}

  setup do
    Jobs.clear()
    start_supervised!(FakePDF)
    start_supervised!(FakeAI)
    :ok
  end

  test "extracts every chunk, merges results, and marks the job done" do
    job = create_upload_job()

    FakePDF.set(%{page_count: 8})

    FakeAI.set_responses([
      ok_response("gemini", "gemini-3.5-flash", "Elixir", 0.9),
      ok_response("gemini", "gemini-3.5-flash", "SQL", 0.8)
    ])

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :done
    assert updated.pages == 8
    assert updated.chunks_total == 2
    assert updated.chunks_done == 2
    assert updated.provider == "gemini"
    assert updated.model == "gemini-3.5-flash"
    assert updated.error == nil
    assert updated.warnings == []
    assert is_map(updated.result)
    assert updated.started_at != nil
    assert updated.finished_at != nil

    calls = FakeAI.calls()
    assert length(calls) == 2
    assert Enum.map(calls, fn call -> call.opts[:index] end) == [1, 2]

    assert Enum.all?(calls, fn call ->
             call.opts[:total] == 2 and
               call.opts[:filename] == "cv.pdf" and
               call.opts[:known_skills] == []
           end)

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "marks the job partial when one chunk fails" do
    job = create_upload_job()

    FakePDF.set(%{page_count: 8})

    FakeAI.set_responses([
      ok_response("gemini", "gemini-3.5-flash", "Elixir", 0.9),
      {:error, :timeout}
    ])

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :partial
    assert updated.chunks_total == 2
    assert updated.chunks_done == 2
    assert updated.error == nil
    assert updated.warnings == ["Chunk 2 failed"]
    assert is_map(updated.result)
    assert updated.provider == "gemini"

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "marks the job partial when the merged result is empty" do
    job = create_upload_job()

    FakePDF.set(%{page_count: 2})

    FakeAI.set_responses([
      {:ok,
       %{
         "skills" => [],
         "experience" => [],
         "education" => [],
         "extraction_confidence" => 0.0
       }, %{provider: "fake", model: "fake-model"}}
    ])

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :partial
    assert updated.warnings == []
    assert is_map(updated.result)
    assert JosjobRagpdf.Result.empty?(updated.result)
    assert updated.provider == "fake"
    assert updated.model == "fake-model"

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "marks the job unreadable when validation fails" do
    job = create_upload_job()

    FakePDF.set(%{validate: {:error, :not_pdf}})
    FakeAI.set_responses([ok_response("gemini", "m", "Elixir", 0.5)])

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :unreadable
    assert updated.error == "File is not a valid PDF"
    assert updated.finished_at != nil
    assert FakeAI.calls() == []

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "marks the job unreadable when page_count fails" do
    job = create_upload_job()

    FakePDF.set(%{validate: :ok, page_count: {:error, :boom}})

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :unreadable
    assert is_binary(updated.error)
    assert updated.finished_at != nil

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "marks the job failed when every chunk fails" do
    job = create_upload_job()

    FakePDF.set(%{page_count: 8})

    FakeAI.set_responses([
      {:error, :timeout},
      {:error, {:all_providers_failed, [:gemini]}}
    ])

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :failed
    assert is_binary(updated.error)
    assert updated.error =~ "All chunks failed"
    assert length(updated.warnings) == 2
    assert updated.chunks_done == 2
    assert updated.result == nil
    assert updated.finished_at != nil

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "downloads a URL source into the job temp dir" do
    job = create_job({:url, "https://example.com/my%20cv.pdf"}, filename: nil)

    FakePDF.set(%{page_count: 2})
    FakeAI.set_responses([ok_response("gemini", "gemini-3.5-flash", "Elixir", 0.9)])

    assert :ok = run_job(job)

    assert_received {:http_download, url, destination}
    assert url == "https://example.com/my%20cv.pdf"
    assert Path.dirname(destination) == Temp.job_dir(job.id)
    assert Path.basename(destination) == "my_cv.pdf"

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :done

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "marks the job failed when the URL download fails" do
    job = create_job({:url, "https://example.com/fail.pdf"})

    assert :ok = run_job(job)

    assert_received {:http_download, "https://example.com/fail.pdf", _destination}

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :failed
    assert updated.error == "Failed to download PDF"
    assert updated.finished_at != nil
  end

  test "decodes a base64 data URI source" do
    data = Base.encode64("%PDF-1.4 fake pdf bytes")
    job = create_job({:base64, "data:application/pdf;base64," <> data}, filename: "cv base64.pdf")

    FakePDF.set(%{page_count: 2})
    FakeAI.set_responses([ok_response("gemini", "gemini-3.5-flash", "Elixir", 0.9)])

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :done

    assert [call] = FakeAI.calls()
    assert call.opts[:filename] == "cv base64.pdf"

    refute File.exists?(Temp.job_dir(job.id))
  end

  test "marks the job failed for invalid base64 data" do
    job = create_job({:base64, "this is not base64!!!"})

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :failed
    assert updated.error == "Invalid base64 PDF data"
  end

  test "marks the job failed when the source is missing" do
    job = create_job(nil)

    assert :ok = run_job(job)

    assert {:ok, updated} = Jobs.get(job.id)
    assert updated.status == :failed
    assert updated.error == "Missing PDF source"
  end

  ## Fake HTTP client (injected as `http: __MODULE__`)

  def download(url, destination) do
    send(self(), {:http_download, url, destination})

    if String.contains?(url, "fail") do
      {:error, :timeout}
    else
      File.mkdir_p!(Path.dirname(destination))
      File.write!(destination, "%PDF-1.4 fake")
      :ok
    end
  end

  ## Helpers

  defp run_job(job, opts \\ []) do
    default_opts = [
      pdf: FakePDF,
      ai: FakeAI,
      http: __MODULE__,
      tmp_dir: Temp.job_dir(job.id)
    ]

    Worker.run(job, Keyword.merge(default_opts, opts))
  end

  defp ok_response(provider, model, skill, confidence) do
    {:ok,
     %{
       "skills" => [
         %{"name" => skill, "confidence" => confidence, "source" => provider}
       ],
       "experience" => [],
       "education" => [],
       "extraction_confidence" => confidence
     }, %{provider: provider, model: model}}
  end

  defp create_upload_job(attrs \\ []) do
    id = Keyword.get(attrs, :id) || JosjobRagpdf.Id.generate()
    dir = Temp.ensure_job_dir(id)
    path = Path.join(dir, "upload.pdf")
    File.write!(path, "%PDF-1.4 fake")

    create_job({:upload, path}, Keyword.put(attrs, :id, id))
  end

  defp create_job(source, attrs \\ []) do
    id = Keyword.get(attrs, :id) || JosjobRagpdf.Id.generate()
    attrs = Keyword.put(attrs, :id, id)
    Temp.ensure_job_dir(id)

    job =
      struct(
        %Job{
          id: id,
          user_id: "user-1",
          status: :queued,
          inserted_at: DateTime.utc_now(),
          filename: "cv.pdf",
          source: source
        },
        attrs
      )

    :ok = Jobs.create(job)
    job
  end
end
