# Explicitly invoked local-Docker fixtures. Never run by application startup.
require Ash.Query
alias Josjob.{Repo, Accounts.User, Orgs.Organization, Orgs.Membership}
alias Josjob.Rbac.{Provisioning, MembershipRole}
alias JosjobJob.{Job, CurriculumVitae}
alias JosjobDoc.Documents.Document

manifest_path = "/tmp/jobs-hiring-qa.json"

if Keyword.get(binding(), :jobs_qa_action) == :cleanup do
  info = manifest_path |> File.read!() |> Jason.decode!()
  org_ids = [info["organization_id"], info["foreign_organization_id"]]

  for id <- org_ids do
    org = Ash.get!(Organization, id, authorize?: false)
    true = String.starts_with?(org.name, "Jobs hiring QA [synthetic]")
  end

  orgs = Enum.map(org_ids, &Ecto.UUID.dump!/1)
  users = Enum.map(~w(owner candidate second foreign newcomer), &Ecto.UUID.dump!(info[&1]["id"]))
  subjects = Enum.map(~w(owner candidate second foreign newcomer), &"user?id=#{info[&1]["id"]}")

  {:ok, _} =
    Repo.transaction(fn ->
      Repo.query!(
        "DELETE FROM job_applications WHERE job_id IN (SELECT id FROM jobs WHERE organization_id = ANY($1::uuid[]))",
        [orgs]
      )

      Repo.query!("DELETE FROM jobs WHERE organization_id = ANY($1::uuid[])", [orgs])

      Repo.query!(
        "DELETE FROM membership_roles WHERE membership_id IN (SELECT id FROM memberships WHERE organization_id = ANY($1::uuid[]))",
        [orgs]
      )

      Repo.query!(
        "DELETE FROM role_permissions WHERE role_id IN (SELECT id FROM roles WHERE organization_id = ANY($1::uuid[]))",
        [orgs]
      )

      Repo.query!("DELETE FROM roles WHERE organization_id = ANY($1::uuid[])", [orgs])
      Repo.query!("DELETE FROM memberships WHERE organization_id = ANY($1::uuid[])", [orgs])
      Repo.query!("DELETE FROM candidate_cv_profiles WHERE user_id = ANY($1::uuid[])", [users])
      Repo.query!("DELETE FROM documents WHERE user_id = ANY($1::uuid[])", [users])
      Repo.query!("DELETE FROM organizations WHERE id = ANY($1::uuid[])", [orgs])

      for table <- ["profiles", "user_details", "user_identities"],
          do: Repo.query!("DELETE FROM #{table} WHERE user_id = ANY($1::uuid[])", [users])

      Repo.query!("DELETE FROM tokens WHERE subject = ANY($1::text[])", [subjects])
      Repo.query!("DELETE FROM users WHERE id = ANY($1::uuid[])", [users])
    end)

  IO.puts("JOBS_HIRING_QA_CLEANED")
  File.rm!(manifest_path)
else
  false = File.exists?(manifest_path)

  {:ok, result} =
    Repo.transaction(fn ->
      suffix = System.system_time(:millisecond)
      password = "local-jobs-qa-password-123"

      user = fn role ->
        User
        |> Ash.Changeset.for_create(:register_with_email, %{
          email: "#{role}-#{suffix}@jobs-qa.example",
          full_name: "#{role} [synthetic QA]",
          password: password
        })
        |> Ash.Changeset.force_change_attributes(%{
          account_type: :personal,
          mandatory_completed: true,
          onboarding_progress: 100
        })
        |> Ash.create!(authorize?: false)
      end

      owner = user.("Owner")
      candidate = user.("Candidate")
      second = user.("Second")
      foreign = user.("Foreign")
      newcomer = user.("Newcomer")

      org =
        Organization
        |> Ash.Changeset.for_create(:create, %{
          name: "Jobs hiring QA [synthetic] #{suffix}",
          user_id: owner.id
        })
        |> Ash.create!(authorize?: false)

      other =
        Organization
        |> Ash.Changeset.for_create(:create, %{
          name: "Jobs hiring QA [synthetic] foreign #{suffix}",
          user_id: foreign.id
        })
        |> Ash.create!(authorize?: false)

      for {person, company, key} <- [
            {owner, org, "employer"},
            {candidate, org, "graduate"},
            {second, org, "graduate"},
            {foreign, other, "employer"}
          ] do
        role = Provisioning.ensure_org_role!(company.id, key)

        membership =
          Membership
          |> Ash.Changeset.for_create(:create, %{
            user_id: person.id,
            organization_id: company.id,
            status: :active
          })
          |> Ash.create!(authorize?: false)

        MembershipRole
        |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
        |> Ash.create!(authorize?: false)
      end

      make_job = fn company, creator, status, title ->
        Job
        |> Ash.Changeset.for_create(:create, %{
          title: title,
          description: "Temporary synthetic verification vacancy. Not a real job.",
          location: "Bandung",
          industry: "Technology",
          employment_type: "full-time",
          work_mode: "remote",
          status: status,
          requirements: ["Elixir", "SQL"],
          salary_min: 5_000_000,
          salary_max: 9_000_000,
          currency: "IDR"
        })
        |> Ash.Changeset.force_change_attributes(%{
          organization_id: company.id,
          created_by: creator.id,
          synthetic: true,
          posted_at: if(status == "active", do: DateTime.utc_now())
        })
        |> Ash.create!(authorize?: false)
      end

      published = make_job.(org, owner, "active", "Browser vacancy [synthetic QA]")
      draft = make_job.(org, owner, "draft", "Private draft [synthetic QA]")
      private = make_job.(other, foreign, "active", "Foreign vacancy [synthetic QA]")

      document =
        Document
        |> Ash.Changeset.for_create(:create, %{
          title: "Selected resume [synthetic QA]",
          url: "https://example.invalid/selected-qa-resume.pdf",
          mime_type: "application/pdf",
          user_id: candidate.id,
          organization_id: org.id
        })
        |> Ash.create!(authorize?: false)

      {:ok, _} =
        CurriculumVitae.save_for(candidate, %{
          "headline" => "Original saved profile [synthetic QA]",
          "resume_document_id" => document.id
        })

      person = fn u -> %{id: u.id, email: to_string(u.email), password: password} end

      %{
        run_id: suffix,
        organization_id: org.id,
        foreign_organization_id: other.id,
        owner: person.(owner),
        candidate: person.(candidate),
        second: person.(second),
        foreign: person.(foreign),
        newcomer: person.(newcomer),
        published_job_id: published.id,
        draft_job_id: draft.id,
        foreign_job_id: private.id,
        resume_document_id: document.id
      }
    end)

  File.write!(manifest_path, Jason.encode!(result))
  IO.puts("JOBS_HIRING_QA_READY")
end
