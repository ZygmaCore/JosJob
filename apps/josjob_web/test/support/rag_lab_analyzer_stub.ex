defmodule JosjobWeb.RagLabAnalyzerStub do
  @moduledoc false
  # Stub test-only untuk `JosjobRag.Analyzer` di `RagLabLiveTest`.
  # Jangan dipakai di runtime.

  def analyze(_user, cv, _opts \\ []) do
    course = %{
      course_id: "course-1",
      class_id: "class-1",
      title: "Kubernetes Dasar",
      matched_skills: ["Kubernetes"],
      coverage: 0.5,
      score: 0.6
    }

    job = %{
      id: "job-1",
      title: "Backend Engineer",
      organization: %{name: "PT Uji"},
      location: "Jakarta",
      employment_type: "full_time",
      work_mode: "remote"
    }

    {:ok,
     %{
       cv_id: cv["cv_id"],
       provider: "stub",
       model: "stub-embedding",
       dimensions: 3,
       semantic: true,
       analyzed_at: DateTime.utc_now(),
       scoring: %{},
       jobs: [
         %{
           job_id: "job-1",
           job: job,
           match_score: 0.75,
           semantic_score: 0.8,
           skill_score: 0.6,
           recency_score: 0.9,
           matched_skills: ["Elixir"],
           missing_skills: ["Kubernetes"],
           explanation: "1 dari 2 skill terpenuhi (Elixir).",
           course: course
         }
       ],
       courses: [course]
     }}
  end
end
