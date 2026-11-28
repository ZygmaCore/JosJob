defmodule JosjobLrn.JobSkillSeeds do
  @moduledoc "Explicit, repeatable demo courses tagged to the CV-demo job requirements."
  require Ash.Query

  alias Josjob.{Accounts.User, Orgs.Organization, Repo}

  alias JosjobLrn.Learning.{
    Course,
    CourseLesson,
    CourseOrganization,
    Section,
    SectionOrganization
  }

  @marker "[Skill Demo]"

  def manifest(path \\ nil) do
    (path || Application.app_dir(:josjob_lrn, "priv/demo/job_skill_courses.json"))
    |> File.read!()
    |> Jason.decode!()
  end

  def seed(opts \\ []) do
    definitions = manifest(opts[:manifest_path])
    organization = organization!(opts[:organization_id])
    owner = Ash.get!(User, organization.user_id, authorize?: false)

    Repo.transaction(fn ->
      # Serialize repeat/concurrent runs because course titles have no unique identity.
      Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", [
        "job-skill-seed:" <> organization.id
      ])

      results = Enum.map(definitions, &ensure_course(&1, organization, owner))

      %{
        organization_id: organization.id,
        courses: length(results),
        created_courses: Enum.count(results, & &1.created?),
        lessons: Enum.sum(Enum.map(results, & &1.lesson_count)),
        course_ids: Enum.map(results, & &1.course.id),
        skill_tags:
          results |> Enum.flat_map(& &1.course.skill_tags) |> Enum.uniq() |> Enum.sort(),
        note:
          "Free self-paced introductory courses with reading, practice and quizzes. Existing course and lesson edits are preserved."
      }
    end)
  end

  defp organization!(nil) do
    case Organization |> Ash.Query.filter(name == "Atveti") |> Ash.read!(authorize?: false) do
      [organization] -> organization
      _ -> raise "Expected one Atveti organization; pass organization_id explicitly instead"
    end
  end

  defp organization!(id), do: Ash.get!(Organization, id, authorize?: false)

  defp ensure_course(definition, organization, owner) do
    section_name = definition["section"] <> " " <> @marker

    section =
      Section
      |> Ash.Query.filter(name == ^section_name and organizations.id == ^organization.id)
      |> Ash.read_one!(authorize?: false)

    section =
      section ||
        create!(
          Section,
          %{
            name: section_name,
            description: "Demo courses connected to job skill requirements."
          },
          owner
        )

    link!(
      SectionOrganization,
      %{section_id: section.id, organization_id: organization.id},
      :unique_section_organization
    )

    title = definition["title"] <> " " <> @marker

    existing =
      Course
      |> Ash.Query.filter(title == ^title and section_id == ^section.id)
      |> Ash.read_one!(authorize?: false)

    course =
      existing ||
        create!(
          Course,
          %{
            title: title,
            description: "Introductory self-paced mini-course. " <> definition["description"],
            skill_tags: definition["skill_tags"],
            section_id: section.id,
            is_active: true,
            is_public: true,
            price_cents: 0,
            currency: "usd"
          },
          owner
        )

    link!(
      CourseOrganization,
      %{course_id: course.id, organization_id: organization.id},
      :unique_course_organization
    )

    old_description =
      "Demo course outline. " <>
        definition["description"] <> " Learning materials have not been published yet."

    course =
      if course.description == old_description do
        course
        |> Ash.Changeset.for_update(
          :update,
          %{description: "Introductory self-paced mini-course. " <> definition["description"]},
          actor: owner
        )
        |> Ash.update!(authorize?: false)
      else
        course
      end

    definitions = Map.fetch!(definition, "lessons")

    Enum.with_index(definitions, 1)
    |> Enum.each(fn {lesson, position} ->
      Repo.insert!(
        %CourseLesson{
          course_id: course.id,
          position: position,
          module_title: lesson["module_title"],
          title: lesson["title"],
          kind: lesson["kind"],
          body: lesson["body"],
          questions: lesson["questions"] || []
        },
        on_conflict: :nothing,
        conflict_target: [:course_id, :position]
      )
    end)

    %{course: course, created?: is_nil(existing), lesson_count: length(definitions)}
  end

  defp create!(resource, attrs, owner) do
    resource
    |> Ash.Changeset.for_create(:create, attrs, actor: owner)
    |> Ash.create!(authorize?: false)
  end

  defp link!(resource, attrs, identity) do
    resource
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: identity)
  end
end
