defmodule JosjobJob.CurriculumVitae do
  @moduledoc "Private CV data sourced from the candidate's account, onboarding and owned documents."
  require Ash.Query
  alias Josjob.Accounts.Profile
  alias Josjob.Repo
  alias JosjobDoc.Documents.Document
  alias JosjobJob.CvProfile

  def get_for(user) do
    profile = metadata(user)
    saved = Profile |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)
    answers = if saved && is_map(saved.answers), do: saved.answers, else: %{}

    documents =
      Document
      |> Ash.Query.filter(
        user_id == ^user.id and is_nil(course_id) and mime_type == "application/pdf"
      )
      |> Ash.Query.sort(created_at: :desc, id: :asc)
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&safe_url?(&1.url))

    resume = profile && Enum.find(documents, &(&1.id == profile.resume_document_id))

    skills =
      fact_list(profile, "skills", list(answers, "skills"))
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&String.downcase/1)

    %{
      identity: %{
        full_name: (profile && profile.full_name) || user.full_name,
        email: to_string(user.email),
        phone: phone(answers, user),
        location: text(answers["country"]) || text(user.address)
      },
      headline: profile && profile.headline,
      summary: profile && profile.summary,
      skills: JosjobJob.EarnedSkills.merge(user, skills),
      editable_skills: skills,
      earned_skill_tags: JosjobJob.EarnedSkills.list(user),
      experience:
        if(has_fact?(profile, "experience"),
          do:
            profile.cv_facts["experience"]
            |> Enum.filter(&is_map/1)
            |> Enum.map(&experience_entry/1),
          else:
            entries(
              answers,
              "employments",
              ~w(name position),
              ~w(name position country industry internship)
            )
        ),
      education:
        if(has_fact?(profile, "education"),
          do:
            profile.cv_facts["education"]
            |> Enum.filter(&is_map/1)
            |> Enum.map(&education_entry/1),
          else: entries(answers, "educations", ~w(name), ~w(name degree major country type))
        ),
      matching_cv_id: profile && profile.cv_facts && profile.cv_facts["cv_id"],
      resume_document: resume && document_json(resume),
      pdf_documents: Enum.map(documents, &document_json/1)
    }
  end

  def matching_facts(user) do
    case metadata(user) do
      nil -> nil
      profile -> profile.cv_facts
    end
  end

  def use_analyzed_cv(user, cv), do: save_for(user, %{}, analyzed_cv: cv)

  def save_for(user, params, opts \\ []) do
    if Map.has_key?(params, "skills") and not valid_skills?(params["skills"]) do
      {:error, :invalid_skills}
    else
      do_save(user, params, opts)
    end
  end

  defp do_save(user, params, opts) do
    result =
      Repo.transaction(fn ->
        Repo.query!("SELECT id FROM users WHERE id::text = $1 FOR UPDATE", [user.id])
        profile = metadata(user)

        attrs =
          params
          |> Map.take(~w(full_name headline summary))
          |> Map.new(fn {key, value} ->
            value = trim(value)

            value =
              if key == "full_name" and is_binary(value),
                do: String.replace(value, ~r/\s+/u, " "),
                else: value

            {key, value}
          end)

        changeset =
          if profile,
            do: Ash.Changeset.for_update(profile, :update, attrs),
            else:
              CvProfile
              |> Ash.Changeset.for_create(:create, attrs)
              |> Ash.Changeset.force_change_attribute(:user_id, user.id)

        changeset =
          if Map.has_key?(params, "resume_document_id") do
            id = params["resume_document_id"]

            case id do
              nil ->
                Ash.Changeset.force_change_attribute(changeset, :resume_document_id, nil)

              id ->
                with {:ok, _} <- Ecto.UUID.cast(id),
                     {:ok, %Document{} = document} <- Ash.get(Document, id, authorize?: false),
                     true <-
                       document.user_id == user.id and is_nil(document.course_id) and
                         document.mime_type == "application/pdf" and safe_url?(document.url) do
                  Ash.Changeset.force_change_attribute(
                    changeset,
                    :resume_document_id,
                    document.id
                  )
                else
                  _ -> Repo.rollback(:invalid_resume_document)
                end
            end
          else
            changeset
          end

        facts =
          if opts[:analyzed_cv],
            do: Map.take(opts[:analyzed_cv], ~w(cv_id skills experience education extraction)),
            else: profile && profile.cv_facts

        facts =
          if Map.has_key?(params, "skills") do
            Map.merge(facts || %{}, %{
              "skills" =>
                params["skills"]
                |> Enum.map(&String.trim/1)
                |> Enum.reject(&(&1 == ""))
                |> Enum.uniq_by(&String.downcase/1),
              "skills_edited" => true
            })
          else
            facts
          end

        changeset =
          if facts,
            do: Ash.Changeset.force_change_attribute(changeset, :cv_facts, facts),
            else: changeset

        if profile,
          do: Ash.update!(changeset, authorize?: false, return_notifications?: true),
          else: Ash.create!(changeset, authorize?: false, return_notifications?: true)
      end)

    case result do
      {:ok, {record, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, record}

      error ->
        error
    end
  end

  defp valid_skills?(values) when is_list(values),
    do: length(values) <= 100 and Enum.all?(values, &(is_binary(&1) and String.length(&1) <= 100))

  defp valid_skills?(_), do: false

  defp has_fact?(profile, key),
    do: profile != nil and is_map(profile.cv_facts) and is_list(profile.cv_facts[key])

  defp fact_list(profile, key, fallback),
    do: if(has_fact?(profile, key), do: profile.cv_facts[key], else: fallback)

  defp experience_entry(entry),
    do: %{
      "name" => text(entry["company"] || entry["name"]),
      "position" => text(entry["title"] || entry["position"]),
      "country" => text(entry["country"]),
      "industry" => text(entry["industry"]),
      "from" => text(entry["start_date"] || entry["from"]),
      "to" => text(entry["end_date"] || entry["to"]),
      "internship" => entry["internship"] == true
    }

  defp education_entry(entry),
    do: %{
      "name" => text(entry["institution"] || entry["name"]),
      "degree" => text(entry["degree"]),
      "major" => text(entry["field"] || entry["major"]),
      "country" => text(entry["country"]),
      "from" => text(entry["start_date"] || entry["from"]),
      "to" => text(entry["end_date"] || entry["to"])
    }

  defp metadata(user),
    do: CvProfile |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)

  defp phone(answers, user),
    do: if(Map.has_key?(answers, "phone"), do: text(answers["phone"]), else: text(user.phone))

  defp list(map, key) do
    case Map.get(map, key) do
      values when is_list(values) -> values
      _ -> []
    end
  end

  defp entries(answers, key, required, fields) do
    list(answers, key)
    |> Enum.filter(fn item -> is_map(item) and Enum.any?(required, &text(item[&1])) end)
    |> Enum.map(fn item ->
      fields
      |> Map.new(fn field ->
        {field, if(field == "internship", do: item[field] == true, else: text(item[field]))}
      end)
      |> Map.put("from", period(item["from"]))
      |> Map.put("to", period(item["to"]))
    end)
  end

  defp period(%{"year" => year} = value) when is_integer(year) and year in 1900..2100 do
    case value["month"] do
      month when is_integer(month) and month in 1..12 ->
        "#{year}-#{String.pad_leading(to_string(month), 2, "0")}"

      _ ->
        to_string(year)
    end
  end

  defp period(_), do: nil

  defp text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  defp text(_), do: nil
  defp trim(value) when is_binary(value), do: text(value)
  defp trim(value), do: value

  defp safe_url?(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host, userinfo: nil}}
      when scheme in ["http", "https"] and is_binary(host) and byte_size(host) > 0 ->
        true

      _ ->
        false
    end
  end

  defp safe_url?(_), do: false
  defp document_json(doc), do: %{id: doc.id, title: doc.title, url: doc.url}
end
