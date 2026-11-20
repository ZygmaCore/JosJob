defmodule JosjobRag.AnalysesDbTest do
  # Real PostgreSQL persistence for analysis snapshots and job matches.
  use Josjob.DataCase, async: false

  alias JosjobRag.Analyses
  alias Josjob.Accounts.User
  alias Josjob.Orgs.Organization
  alias JosjobJob.Job

  setup do
    user =
      User
      |> Ash.Changeset.for_create(:register_with_email, %{
        email: "rag-analyses-#{System.unique_integer([:positive])}@example.com",
        full_name: "RAG analyses tester",
        password: "password123"
      })
      |> Ash.create!(authorize?: false)

    org =
      Organization
      |> Ash.Changeset.for_create(:create, %{name: "RAG analyses org", user_id: user.id})
      |> Ash.create!(authorize?: false)

    job =
      Job
      |> Ash.Changeset.for_create(:create, %{
        "title" => "Backend engineer",
        "description" => "Build and operate APIs.",
        "location" => "Bandung",
        "industry" => "Technology",
        "employment_type" => "full-time",
        "work_mode" => "hybrid",
        "requirements" => ["Elixir", "SQL"],
        "status" => "active"
      })
      |> Ash.Changeset.force_change_attribute(:organization_id, org.id)
      |> Ash.Changeset.force_change_attribute(:created_by, user.id)
      |> Ash.Changeset.force_change_attribute(:posted_at, DateTime.utc_now())
      |> Ash.create!(authorize?: false)

    %{user: user, org: org, job: job}
  end

  defp result(job, overrides \\ %{}) do
    Map.merge(
      %{
        cv_id: "cv-db-1",
        provider: "local",
        model: "hashed-bow-v1",
        semantic: false,
        analyzed_at: DateTime.utc_now(),
        jobs: [
          %{
            job_id: job.id,
            job: job,
            match_score: 0.75,
            match: 0.7,
            semantic_score: nil,
            skill_score: 0.5,
            recency_score: 1.0,
            matched_skills: ["Elixir"],
            missing_skills: ["SQL"],
            explanation: "1 dari 2 skill terpenuhi (Elixir)",
            course: nil
          }
        ]
      },
      overrides
    )
  end

  test "save/3 then get/2 round-trips the analysis and its matches", %{
    user: user,
    org: org,
    job: job
  } do
    cv = %{"cv_id" => "cv-db-1", "skills" => ["Elixir"]}

    assert {:ok, analysis_id} = Analyses.save(user, cv, result(job))
    assert is_binary(analysis_id)

    assert {:ok, analysis} = Analyses.get(user, "cv-db-1")
    assert analysis.cv_id == "cv-db-1"
    assert analysis.provider == "local"
    assert analysis.model == "hashed-bow-v1"
    assert analysis.semantic == false
    assert analysis.persisted == true
    assert is_binary(analysis.analyzed_at)

    assert [match] = analysis.jobs
    assert match.job_id == job.id
    assert match.rank == 1
    assert match.match_score == 0.75
    assert match.matched_skills == ["Elixir"]
    assert match.missing_skills == ["SQL"]
    assert match.course == nil
    assert match.job.title == "Backend engineer"
    assert match.job.company == org.name

    assert analysis.courses == []
  end

  test "saving again replaces the previous snapshot", %{user: user, job: job} do
    cv = %{"cv_id" => "cv-db-1", "skills" => ["Elixir"]}
    assert {:ok, _id} = Analyses.save(user, cv, result(job))

    improved =
      result(job, %{
        jobs: [
          %{
            job_id: job.id,
            job: job,
            match_score: 0.95,
            match: 0.9,
            semantic_score: 0.8,
            skill_score: 1.0,
            recency_score: 1.0,
            matched_skills: ["Elixir", "SQL"],
            missing_skills: [],
            explanation: "Semua skill terpenuhi",
            course: nil
          }
        ]
      })

    assert {:ok, _id} = Analyses.save(user, cv, improved)

    assert {:ok, analysis} = Analyses.get(user, "cv-db-1")
    assert [match] = analysis.jobs
    assert match.match_score == 0.95
    assert match.missing_skills == []
  end

  test "get/2 reports unknown CVs as not found", %{user: user} do
    assert {:error, :not_found} = Analyses.get(user, "missing-cv")
  end

  test "save/3 requires a cv_id", %{user: user} do
    assert {:error, :missing_cv_id} = Analyses.save(user, %{}, %{jobs: []})
  end

  test "delete/2 removes the snapshot", %{user: user, job: job} do
    cv = %{"cv_id" => "cv-db-1", "skills" => ["Elixir"]}
    assert {:ok, _id} = Analyses.save(user, cv, result(job))

    assert {:ok, 1} = Analyses.delete(user, "cv-db-1")
    assert {:error, :not_found} = Analyses.get(user, "cv-db-1")
  end
end
