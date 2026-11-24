# Explicit local-only browser fixtures. Not loaded by startup or production seeds.
require Ash.Query
alias Josjob.{Repo, Accounts.User}
alias JosjobLrn.Learning.{Section, Course, Class}
alias JosjobDoc.Documents.Document
manifest = "/tmp/candidate-journey-qa.json"

if Keyword.get(binding(), :candidate_journey_action) == :cleanup do
  info = manifest |> File.read!() |> Jason.decode!()
  course = Ash.get!(Course, info["course_id"], authorize?: false)
  true = String.starts_with?(course.title, "Docker foundations [Journey QA]")
  candidate_id = Ecto.UUID.dump!(info["candidate"]["id"])
  class_id = Ecto.UUID.dump!(info["class_id"])
  course_id = Ecto.UUID.dump!(course.id)

  {:ok, _} = Repo.transaction(fn ->
    %{rows: [[0]]} = Repo.query!("SELECT count(*) FROM enrollments WHERE class_id = $1 AND student_id != $2", [class_id, candidate_id])
    Repo.query!("DELETE FROM enrollments WHERE class_id = $1 AND student_id = $2", [class_id, candidate_id])
    Repo.query!("DELETE FROM documents WHERE course_id = $1", [course_id])
    Repo.query!("DELETE FROM classes WHERE id = $1 AND course_id = $2", [class_id, course_id])
    Repo.query!("DELETE FROM courses WHERE id = $1", [course_id])
    Repo.query!("DELETE FROM sections WHERE id = $1", [Ecto.UUID.dump!(info["section_id"])])

    case User |> Ash.Query.filter(email == ^info["registration_email"]) |> Ash.read_one!(authorize?: false) do
      nil -> :ok
      user ->
        id = Ecto.UUID.dump!(user.id)
        for table <- ["candidate_cv_profiles", "profiles", "user_details", "user_identities"], do: Repo.query!("DELETE FROM #{table} WHERE user_id = $1", [id])
        Repo.query!("DELETE FROM tokens WHERE subject = $1", ["user?id=#{user.id}"])
        Repo.query!("DELETE FROM users WHERE id = $1", [id])
    end
  end)
  Code.eval_string(File.read!(Path.join(__DIR__, "jobs_hiring.exs")), jobs_qa_action: :cleanup)
  File.rm!(manifest)
  IO.puts("CANDIDATE_JOURNEY_CLEANED")
else
  false = File.exists?(manifest)
  Code.eval_file(Path.join(__DIR__, "jobs_hiring.exs"))
  info = "/tmp/jobs-hiring-qa.json" |> File.read!() |> Jason.decode!()
  candidate = Ash.get!(User, info["candidate"]["id"], authorize?: false)
  {:ok, _} = JosjobJob.CurriculumVitae.save_for(candidate, %{"headline" => "", "resume_document_id" => nil})
  job = Ash.get!(JosjobJob.Job, info["published_job_id"], authorize?: false)
  job |> Ash.Changeset.for_update(:update, %{requirements: ["Elixir", "Docker"]}) |> Ash.update!(authorize?: false)
  title = "Docker foundations [Journey QA] #{info["run_id"]}"
  section = Section |> Ash.Changeset.for_create(:create, %{name: title}) |> Ash.create!(authorize?: false)
  course = Course |> Ash.Changeset.for_create(:create, %{title: title, description: "Synthetic local journey test. Practice Docker fundamentals.", section_id: section.id, is_public: true, price_cents: 0}) |> Ash.create!(authorize?: false)
  class = Class |> Ash.Changeset.for_create(:create, %{title: "Docker practice [synthetic QA]", course_id: course.id, organization_id: info["organization_id"], instructor_id: info["owner"]["id"]}) |> Ash.create!(authorize?: false)
  Document |> Ash.Changeset.for_create(:create, %{title: "Practice handout [synthetic QA]", url: "http://localhost:4000/assets/demo-cvs/backend.pdf", user_id: info["owner"]["id"], organization_id: info["organization_id"], course_id: course.id}) |> Ash.create!(authorize?: false)
  info = Map.merge(info, %{course_id: course.id, class_id: class.id, section_id: section.id, course_title: title, registration_email: "registration-#{info["run_id"]}@journey-qa.example"})
  File.write!(manifest, Jason.encode!(info))
  IO.puts("CANDIDATE_JOURNEY_READY")
end
