defmodule JosjobRag.ApplicationSuggestions do
  @moduledoc "Read-only skill gaps and accessible learning suggestions for one application."

  alias Josjob.Authz
  alias JosjobJob.{CurriculumVitae, Listings}
  alias JosjobLrn.Learning
  alias JosjobRag.{Analyses, Ranker, Text}

  def get(user, job_id) do
    with {:ok, job} <- Listings.get(user, job_id),
         :ok <- accepting_applications(job),
         {:ok, skills, source} <- cv_skills(user) do
      requirements = Text.requirement_list(job.requirements)
      {matched, missing} = Text.split_skills(requirements, skills)

      status =
        cond do
          requirements == [] -> "no_requirements"
          skills == [] -> "cv_required"
          missing == [] -> "matched"
          true -> "gap"
        end

      courses = if status == "gap", do: recommendations(user, missing), else: []

      {:ok,
       %{
         status: status,
         source: source,
         matched_skills: if(status == "cv_required", do: [], else: matched),
         missing_skills: if(status == "cv_required", do: [], else: missing),
         courses: courses,
         uncovered_skills:
           if(status == "gap",
             do:
               Enum.reject(missing, fn skill ->
                 Enum.any?(courses, fn course ->
                   Enum.any?(course.matched_skills, &Text.same_skill?(&1, skill))
                 end)
               end),
             else: []
           )
       }}
    end
  end

  defp accepting_applications(%{status: "active"}), do: :ok
  defp accepting_applications(_), do: {:error, :job_closed}

  # Reuse saved extraction facts; opening Apply never sends a PDF to an AI service.
  defp cv_skills(user) do
    facts = CurriculumVitae.matching_facts(user)

    if is_map(facts) and Map.has_key?(facts, "skills") do
      source =
        if facts["cv_id"] && facts["skills_edited"] != true,
          do: "analyzed_cv",
          else: "saved_profile"

      {:ok, Text.requirement_list(facts["skills"]), source}
    else
      extracted_skills(user)
    end
  end

  defp extracted_skills(user) do
    case Analyses.cv(user) do
      {:ok, cv} ->
        case Text.requirement_list(cv["skills"]) do
          [] -> profile_skills(user)
          skills -> {:ok, skills, "analyzed_cv"}
        end

      {:error, :not_found} ->
        profile_skills(user)

      error ->
        error
    end
  end

  defp profile_skills(user),
    do: {:ok, CurriculumVitae.get_for(user).skills, "saved_profile"}

  defp recommendations(user, missing) do
    org_ids = user |> Authz.member_orgs() |> Enum.map(& &1.id)

    courses =
      Learning.visible_courses(org_ids)
      |> Enum.map(fn course ->
        # Match the catalog's class visibility before choosing a class or exposing a count.
        classes =
          course.classes
          |> Enum.filter(&(course.is_public or &1.organization_id in org_ids))
          |> Enum.sort_by(&{DateTime.to_unix(&1.created_at, :microsecond), &1.id})

        %{course | classes: classes}
      end)

    Ranker.recommend_courses(missing, courses)
    |> Enum.map(fn recommendation ->
      course = recommendation.course

      %{
        id: course.id,
        title: course.title,
        description: course.description,
        section: course.section && %{name: course.section.name},
        industries: Enum.map(course.industries, &%{name: &1.name}),
        class_count: length(course.classes),
        class_id: recommendation.class_id,
        price_cents: course.price_cents,
        currency: course.currency,
        matched_skills: recommendation.matched_skills
      }
    end)
  end
end
