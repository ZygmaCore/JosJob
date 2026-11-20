defmodule JosjobRag.AnalyzerTest do
  use ExUnit.Case, async: false

  alias JosjobRag.Analyzer
  alias JosjobRag.Test.{FakeEmbeddings, FakeVectorStore}

  @now ~U[2026-11-18 00:00:00Z]

  # Simulates PostgreSQL/pgvector being absent or not migrated.
  defmodule BrokenStore do
    def dimensions, do: 1536
    def dominant_space(_owner_type), do: {:error, :not_migrated}
    def hashes(_owner_type, _ids, _provider, _model), do: {:error, :not_migrated}
    def delete_space(_owner_type, _provider, _model), do: {:error, :not_migrated}
  end

  setup do
    FakeVectorStore.start!()
    :ok
  end

  defp jobs do
    [
      %{
        id: "job-1",
        title: "Backend Engineer (Go, PostgreSQL)",
        description: "Design APIs and operate PostgreSQL databases",
        industry: "Technology",
        employment_type: "full-time",
        work_mode: "remote",
        location: "Jakarta",
        requirements: ["Go", "PostgreSQL", "Kubernetes"],
        posted_at: @now
      },
      %{
        id: "job-2",
        title: "Graphic Designer",
        description: "Brand identity, typography, and illustration",
        industry: "Design",
        employment_type: "full-time",
        work_mode: "onsite",
        location: "Bandung",
        requirements: ["Graphic Design", "Photoshop"],
        posted_at: @now
      }
    ]
  end

  defp courses do
    [
      %{
        id: "course-1",
        title: "Kubernetes for Backend Engineers",
        description: "Deploy and scale containerized services",
        industries: ["Technology"],
        section: %{title: "Engineering"},
        classes: [%{id: "class-1"}]
      },
      %{
        id: "course-2",
        title: "Graphic Design Fundamentals",
        description: "Brand identity and typography",
        industries: ["Design"],
        section: %{title: "Creative"},
        classes: [%{id: "class-2"}]
      }
    ]
  end

  defp cv do
    %{
      "cv_id" => "cv-live-1",
      "skills" => ["Go", "PostgreSQL"],
      "experience" => [
        %{"title" => "Backend Engineer", "company" => "Acme", "description" => "Built APIs"}
      ],
      "education" => [
        %{"degree" => "BSc", "institution" => "University", "field" => "Computer Science"}
      ]
    }
  end

  defp analyze(opts) do
    Analyzer.analyze(
      nil,
      cv(),
      Keyword.merge(
        [
          jobs: jobs(),
          courses: courses(),
          vector_store: FakeVectorStore,
          embeddings: FakeEmbeddings,
          now: @now,
          limit: 5
        ],
        opts
      )
    )
  end

  test "ranks jobs and attaches a real course for missing skills" do
    assert {:ok, result} = analyze([])

    assert result.cv_id == "cv-live-1"
    assert result.semantic == true
    assert result.provider == "local"
    assert result.model == "hashed-bow-v1"
    assert result.dimensions == 1536
    assert result.scoring.semantic == 0.6

    assert [best, other] = result.jobs
    assert best.job_id == "job-1"
    assert other.job_id == "job-2"
    assert best.semantic_score != nil
    assert best.missing_skills == ["Kubernetes"]
    assert best.course.course_id == "course-1"
    assert best.course.class_id == "class-1"

    assert other.missing_skills == ["Graphic Design", "Photoshop"]
    assert other.course.course_id == "course-2"
    assert other.course.class_id == "class-2"

    assert Enum.map(result.courses, & &1.course_id) |> Enum.sort() == ["course-1", "course-2"]
    assert Enum.all?(result.courses, &(&1.jobs_covered == 1))
  end

  test "degrades to skill-only ranking when the vector store is unavailable" do
    assert {:ok, result} = analyze(vector_store: BrokenStore)

    assert result.semantic == false
    assert result.provider == nil
    assert result.model == nil
    assert Enum.all?(result.jobs, &is_nil(&1.semantic_score))

    assert Enum.map(result.jobs, & &1.job_id) |> Enum.sort() == ["job-1", "job-2"]
    assert Enum.all?(result.jobs, &(&1.match_score > 0.0))
  end

  test "respects the limit and the injected clock" do
    assert {:ok, result} = analyze(limit: 1)
    assert length(result.jobs) == 1
    assert result.analyzed_at == @now
  end

  test "index_cv requires an id" do
    assert Analyzer.index_cv(%{"skills" => ["Go"]}) == {:error, :missing_cv_id}
    assert Analyzer.index_cv(%{"skills" => ["Go"]}, cv_id: "") == {:error, :missing_cv_id}
  end

  test "index_jobs is idempotent thanks to content hashes" do
    opts = [
      vector_store: FakeVectorStore,
      embeddings: FakeEmbeddings,
      space: %{provider: "local", model: "hashed-bow-v1", dimensions: 1536}
    ]

    assert {:ok, 2} = Analyzer.index_jobs(jobs(), opts)
    assert {:ok, 2} = Analyzer.index_jobs(jobs(), opts)
  end

  test "index_cv stores a CV vector under the given id" do
    opts = [
      vector_store: FakeVectorStore,
      embeddings: FakeEmbeddings,
      space: %{provider: "local", model: "hashed-bow-v1", dimensions: 1536}
    ]

    assert Analyzer.index_cv(cv(), opts) == :ok

    assert {:ok, %{"cv-live-1" => vector}} =
             FakeVectorStore.vectors(:cv, ["cv-live-1"], "local", "hashed-bow-v1")

    assert length(vector) == 1536
  end
end
