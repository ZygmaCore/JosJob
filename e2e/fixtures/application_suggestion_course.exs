# Temporary local-only course for positive HTTP recommendation coverage.
require Ash.Query
alias Josjob.{Repo, Accounts.User, Orgs.Organization}
alias JosjobLrn.Learning.{Section, Course, Class}
manifest = "/tmp/application-suggestion-course-qa.json"
marker = "SQL fundamentals [Suggestion API QA]"

if Keyword.get(binding(), :suggestion_qa_action) == :cleanup do
  info = manifest |> File.read!() |> Jason.decode!()
  course = Ash.get!(Course, info["course_id"], authorize?: false)
  section = Ash.get!(Section, info["section_id"], authorize?: false)
  true = course.title == info["title"] and String.starts_with?(course.title, marker)
  true = course.section_id == section.id and section.name == course.title

  {:ok, :ok} =
    Repo.transaction(fn ->
      course_id = Ecto.UUID.dump!(course.id)
      class_id = Ecto.UUID.dump!(info["class_id"])

      %{rows: [[0]]} =
        Repo.query!("SELECT count(*) FROM enrollments WHERE class_id = $1", [class_id])

      %{num_rows: 1} =
        Repo.query!("DELETE FROM classes WHERE id = $1 AND course_id = $2", [class_id, course_id])

      %{num_rows: 1} = Repo.query!("DELETE FROM courses WHERE id = $1", [course_id])

      %{num_rows: 1} =
        Repo.query!("DELETE FROM sections WHERE id = $1", [Ecto.UUID.dump!(section.id)])

      :ok
    end)

  File.rm!(manifest)
  IO.puts("APPLICATION_SUGGESTION_COURSE_CLEANED")
else
  false = File.exists?(manifest)

  {:ok, info} =
    Repo.transaction(fn ->
      owner =
        User
        |> Ash.Query.filter(email == "employer@cv-demo.josjob.test")
        |> Ash.read_one!(authorize?: false)

      org =
        Organization
        |> Ash.Query.filter(user_id == ^owner.id and name == "CV Relevance Demo Company [Demo]")
        |> Ash.read_one!(authorize?: false)

      title = "#{marker} #{System.system_time(:millisecond)}"

      section =
        Section
        |> Ash.Changeset.for_create(:create, %{name: title})
        |> Ash.create!(authorize?: false)

      course =
        Course
        |> Ash.Changeset.for_create(:create, %{
          title: title,
          description: "Synthetic SQL learning fixture for local API verification.",
          section_id: section.id,
          is_public: true,
          price_cents: 2500,
          currency: "usd"
        })
        |> Ash.create!(authorize?: false)

      class =
        Class
        |> Ash.Changeset.for_create(:create, %{
          title: "SQL class [synthetic QA]",
          course_id: course.id,
          organization_id: org.id,
          instructor_id: owner.id
        })
        |> Ash.create!(authorize?: false)

      %{title: title, course_id: course.id, class_id: class.id, section_id: section.id}
    end)

  File.write!(manifest, Jason.encode!(info))
  IO.puts("APPLICATION_SUGGESTION_COURSE_CREATED")
end
