defmodule JosjobRag.DemoSeeds do
  @moduledoc "Explicit, additive fictional CV accounts and jobs for relevance testing. Never run on startup."
  require Ash.Query

  alias Josjob.{Repo, Accounts.User, Accounts.Profile, Orgs.Organization, Orgs.Membership}
  alias Josjob.Rbac.{MembershipRole, Provisioning}
  alias JosjobDoc.Documents.Document
  alias JosjobJob.{Job, CurriculumVitae}
  alias JosjobRag.{Analyses, Analyzer, PdfClient}

  @marker "josjob-cv-relevance-v1"
  @password "JosJobDemo123!"
  @organization "CV Relevance Demo Company [Demo]"

  def manifest do
    :josjob_rag
    |> Application.app_dir("priv/demo/cv_relevance.json")
    |> File.read!()
    |> Jason.decode!()
  end

  def seed(opts \\ []) do
    data = manifest()
    true = data["version"] == @marker

    pdf_dir =
      Keyword.get(opts, :pdf_dir, Application.app_dir(:josjob_web, "priv/static/assets/demo-cvs"))

    base_url =
      Keyword.get(
        opts,
        :base_url,
        System.get_env("JOSJOB_DEMO_BASE_URL", "http://localhost:4000")
      )

    # Validate every fixture before writing any account or job.
    versions =
      Map.new(data["candidates"], fn person ->
        path = Path.join(pdf_dir, person["slug"] <> ".pdf")
        {:ok, version} = PdfClient.version(%{path: path})
        {person["slug"], version}
      end)

    Repo.transaction(
      fn ->
        Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", [@marker])
        employer = ensure_user("employer@cv-demo.josjob.test", "CV Relevance Recruiter [Demo]")
        organization = ensure_organization(employer)
        ensure_role(employer, organization, "employer")
        jobs = Enum.map(data["jobs"], &ensure_job(&1, employer, organization))
        active_jobs = Enum.filter(jobs, &(&1.status == "active"))

        candidates =
          Enum.map(data["candidates"], fn person ->
            expected_email = person["slug"] <> "@cv-demo.josjob.test"
            true = person["email"] == expected_email
            user = ensure_user(expected_email, person["name"])
            ensure_role(user, organization, "graduate")
            ensure_profile(user, person)
            document = ensure_document(user, organization, person, base_url)

            if is_nil(CurriculumVitae.get_for(user).headline) do
              {:ok, _} =
                CurriculumVitae.save_for(user, %{
                  "headline" => person["headline"],
                  "summary" => person["summary"],
                  "resume_document_id" => document.id
                })
            end

            cv_id = Map.fetch!(versions, person["slug"])

            case Analyses.cv(user, cv_id) do
              {:error, :not_found} ->
                cv =
                  Map.take(person, ["skills", "experience", "education"])
                  |> Map.merge(%{
                    "cv_id" => cv_id,
                    "demo_seed" => @marker,
                    "extraction" => %{
                      "status" => "done",
                      "provider" => "synthetic_demo",
                      "warnings" => ["Fictional seeded CV facts; no AI extraction was performed."]
                    }
                  })

                {:ok, result} =
                  Analyzer.analyze(user, cv, jobs: active_jobs, courses: [], limit: 50)

                {:ok, _} = Analyses.save(user, cv, result)

              {:ok, _existing} ->
                :ok

              {:error, reason} ->
                Repo.rollback(reason)
            end

            {:ok, cv} = Analyses.cv(user, cv_id)

            %{
              email: expected_email,
              name: user.full_name,
              user_id: user.id,
              cv_id: cv_id,
              pdf: person["slug"] <> ".pdf",
              categories: cv["matching_profile"]["categories"]
            }
          end)

        %{
          marker: @marker,
          organization_id: organization.id,
          employer: to_string(employer.email),
          candidates: candidates,
          jobs: length(jobs),
          active_jobs: length(active_jobs),
          initial_password: @password,
          note:
            "Fictional local demo only. Existing matching records and changed passwords are preserved."
        }
      end,
      timeout: 120_000
    )
  end

  defp ensure_user(email, name) do
    case User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false) do
      nil ->
        User
        |> Ash.Changeset.for_create(:register_with_email, %{
          email: email,
          full_name: name,
          password: @password,
          address: "Bandung, Indonesia"
        })
        |> Ash.Changeset.force_change_attributes(%{
          account_type: :personal,
          mandatory_completed: true,
          onboarding_progress: 100
        })
        |> Ash.create!(authorize?: false)

      user ->
        unless user.full_name == name and not user.is_superuser,
          do: raise("Refusing to reuse an account outside this demo: #{email}")

        user
    end
  end

  defp ensure_organization(employer) do
    case Organization
         |> Ash.Query.filter(name == ^@organization)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        Organization
        |> Ash.Changeset.for_create(:create, %{
          name: @organization,
          user_id: employer.id,
          address: "Bandung, Indonesia",
          additional_info: @marker
        })
        |> Ash.create!(authorize?: false)

      organization ->
        unless organization.user_id == employer.id and organization.additional_info == @marker,
          do: raise("Refusing to reuse an organization outside this demo")

        organization
    end
  end

  defp ensure_role(user, organization, key) do
    role = Provisioning.ensure_org_role!(organization.id, key)

    membership =
      Membership
      |> Ash.Query.filter(user_id == ^user.id and organization_id == ^organization.id)
      |> Ash.read_one!(authorize?: false)

    membership =
      membership ||
        Membership
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          organization_id: organization.id,
          status: :active
        })
        |> Ash.create!(authorize?: false)

    unless MembershipRole
           |> Ash.Query.filter(membership_id == ^membership.id and role_id == ^role.id)
           |> Ash.read_one!(authorize?: false) do
      MembershipRole
      |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
      |> Ash.create!(authorize?: false)
    end
  end

  defp ensure_profile(user, person) do
    unless Profile |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false) do
      answers = %{
        "demo_seed" => @marker,
        "country" => "Indonesia",
        "skills" => person["skills"],
        "employments" =>
          Enum.map(person["experience"], fn entry ->
            %{
              "name" => entry["company"],
              "position" => entry["title"],
              "country" => "Indonesia",
              "from" => %{"year" => 2024, "month" => 1},
              "to" => %{"year" => 2026, "month" => 10}
            }
          end),
        "educations" =>
          Enum.map(person["education"], fn entry ->
            %{
              "name" => entry["institution"],
              "degree" => entry["degree"],
              "major" => entry["field"],
              "from" => %{"year" => 2020},
              "to" => %{"year" => 2023},
              "country" => "Indonesia"
            }
          end)
      }

      Profile
      |> Ash.Changeset.new()
      |> Ash.Changeset.force_change_attribute(:user_id, user.id)
      |> Ash.Changeset.for_create(:upsert_answers, %{
        answers: answers,
        answers_updated_at: DateTime.utc_now()
      })
      |> Ash.create!(authorize?: false)
    end
  end

  defp ensure_document(user, organization, person, base_url) do
    title = person["headline"] <> " [CV Demo PDF]"

    case Document
         |> Ash.Query.filter(user_id == ^user.id and title == ^title)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        Document
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attributes(%{
          user_id: user.id,
          organization_id: organization.id
        })
        |> Ash.Changeset.for_create(:create, %{
          title: title,
          url:
            String.trim_trailing(base_url, "/") <> "/assets/demo-cvs/" <> person["slug"] <> ".pdf",
          mime_type: "application/pdf",
          description: @marker <> ": fictional public PDF fixture"
        })
        |> Ash.create!(authorize?: false)

      document ->
        unless document.organization_id == organization.id and
                 document.description == @marker <> ": fictional public PDF fixture",
               do: raise("Existing document does not belong to this demo")

        document
    end
  end

  defp ensure_job(definition, employer, organization) do
    title = definition["title"]

    case Job
         |> Ash.Query.filter(organization_id == ^organization.id and title == ^title)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        attrs =
          definition
          |> Map.take(
            ~w(title description location industry employment_type work_mode requirements salary_min salary_max status)
          )
          |> Map.put("currency", "IDR")
          |> Map.put("highlights", [
            "Fictional CV relevance demo",
            "Synthetic salary and requirements"
          ])

        Job
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.force_change_attributes(%{
          organization_id: organization.id,
          created_by: employer.id,
          synthetic: true,
          posted_at:
            if(definition["status"] != "draft",
              do: DateTime.add(DateTime.utc_now(), -definition["posted_days_ago"] * 86_400)
            )
        })
        |> Ash.create!(authorize?: false)

      job ->
        unless job.synthetic and job.created_by == employer.id,
          do: raise("Existing job does not belong to this demo: #{title}")

        job
    end
  end
end
