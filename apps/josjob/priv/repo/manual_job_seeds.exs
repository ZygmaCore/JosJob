# Explicit local-demo seed. Never called by application startup or normal seeds.
# Run against the local Docker release; see docs/manual-job-testing.md.
require Ash.Query
alias Josjob.{Repo, Accounts.User, Accounts.Profile, Orgs.Organization, Orgs.Membership}
alias Josjob.Rbac.{MembershipRole, Provisioning}
alias JosjobJob.{Job, Applications, CurriculumVitae}

password = "JosJobDemo123!"
organization_name = "JosJob Demo Company [Demo]"
marker = "josjob-manual-jobs-v1"

ensure_user = fn email, name ->
  case User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false) do
    nil ->
      User
      |> Ash.Changeset.for_create(:register_with_email, %{
        email: email,
        full_name: name,
        password: password,
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
        do: raise("Existing account does not match the manual demo: #{email}")

      user
  end
end

employer = ensure_user.("employer@demo.josjob.test", "Demo Recruiter")
candidate = ensure_user.("candidate@demo.josjob.test", "Demo Candidate")

organization =
  case Organization
       |> Ash.Query.filter(name == ^organization_name)
       |> Ash.read_one!(authorize?: false) do
    nil ->
      Organization
      |> Ash.Changeset.for_create(:create, %{
        name: organization_name,
        user_id: employer.id,
        address: "Bandung, Indonesia",
        additional_info: marker
      })
      |> Ash.create!(authorize?: false)

    existing ->
      unless existing.user_id == employer.id and existing.additional_info == marker,
        do: raise("Existing organization does not match the manual demo")

      existing
  end

for {user, key} <- [{employer, "employer"}, {candidate, "graduate"}] do
  role = Provisioning.ensure_org_role!(organization.id, key)

  membership =
    Membership
    |> Ash.Query.filter(user_id == ^user.id and organization_id == ^organization.id)
    |> Ash.read_one!(authorize?: false) ||
      Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: user.id,
        organization_id: organization.id,
        status: :active
      })
      |> Ash.create!(authorize?: false)

  existing_role =
    MembershipRole
    |> Ash.Query.filter(membership_id == ^membership.id and role_id == ^role.id)
    |> Ash.read_one!(authorize?: false)

  unless existing_role do
    MembershipRole
    |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
    |> Ash.create!(authorize?: false)
  end
end

unless Profile
       |> Ash.Query.filter(user_id == ^candidate.id)
       |> Ash.read_one!(authorize?: false) do
  Profile
  |> Ash.Changeset.for_create(:upsert_answers, %{
    user_id: candidate.id,
    answers_updated_at: DateTime.utc_now(),
    answers: %{
      "country" => "Indonesia",
      "skills" => ["Elixir", "Flutter", "SQL", "Git", "Communication"],
      "educations" => [
        %{
          "name" => "Demo Technology Institute",
          "degree" => "Bachelor",
          "major" => "Computer Science",
          "country" => "Indonesia"
        }
      ],
      "employments" => [
        %{
          "name" => "Demo Studio",
          "position" => "Software Engineering Intern",
          "country" => "Indonesia",
          "industry" => "Technology"
        }
      ]
    }
  })
  |> Ash.create!(authorize?: false)
end

unless CurriculumVitae.get_for(candidate).headline do
  {:ok, _} =
    CurriculumVitae.save_for(candidate, %{
      "headline" => "Junior developer - synthetic manual-testing profile",
      "summary" =>
        "Demo candidate interested in building useful web and mobile products. This profile is fictional and is provided for local manual testing."
    })
end

# The first five are fresh opportunities; the next five have example applications.
definitions = [
  {"Junior Backend Developer", "Bandung", "Technology", "full-time", "hybrid", 7_000_000,
   11_000_000, ["Elixir", "Phoenix", "PostgreSQL"],
   "Build APIs and maintain reliable services with a small product team.", nil},
  {"Flutter Developer", "Jakarta", "Technology", "full-time", "remote", 8_000_000, 13_000_000,
   ["Flutter", "Dart", "REST APIs"],
   "Create accessible mobile and web experiences for our demo product.", nil},
  {"UI/UX Design Intern", "Bandung", "Design", "internship", "onsite", 2_500_000, 4_000_000,
   ["Figma", "Prototyping", "User research"],
   "Help design clear interfaces and test prototypes with the product team.", nil},
  {"Data Analyst", "Surabaya", "Analytics", "contract", "hybrid", 6_000_000, 10_000_000,
   ["SQL", "Python", "Data visualization"],
   "Turn product data into useful reports and explain findings to stakeholders.", nil},
  {"Content Writer", "Yogyakarta", "Marketing", "freelance", "remote", 3_000_000, 5_000_000,
   ["Writing", "SEO", "Research"],
   "Write helpful product guides and collaborate with our design team.", nil},
  {"QA Engineer", "Jakarta", "Technology", "full-time", "hybrid", 6_000_000, 9_000_000,
   ["Test planning", "Playwright", "API testing"],
   "Plan practical tests and investigate product defects. Sample application starts at Applied.",
   "applied"},
  {"Frontend Developer", "Bandung", "Technology", "full-time", "remote", 7_000_000, 12_000_000,
   ["JavaScript", "HTML", "CSS"],
   "Build responsive product screens. Sample application starts at Reviewing.", "reviewing"},
  {"Product Designer", "Jakarta", "Design", "full-time", "hybrid", 8_000_000, 14_000_000,
   ["Figma", "Design systems", "User research"],
   "Improve the end-to-end product experience. Sample application starts at Interview.",
   "interview"},
  {"Customer Support Specialist", "Semarang", "Customer Service", "part-time", "onsite",
   3_000_000, 5_000_000, ["Communication", "Problem solving", "Documentation"],
   "Help customers resolve questions clearly. Sample application starts at Offer.", "offer"},
  {"DevOps Engineer", "Jakarta", "Technology", "full-time", "remote", 10_000_000, 16_000_000,
   ["Docker", "Linux", "CI/CD"],
   "Maintain the demo delivery pipeline. Sample application is already Hired with read-only chat.",
   "hired"},
  {"Technical Writer", "Bandung", "Technology", "contract", "remote", 5_000_000, 8_000_000,
   ["Documentation", "Git", "APIs"],
   "Draft vacancy for testing editing and publication. Visible to the employer until published.",
   :draft},
  {"Operations Assistant", "Surabaya", "Operations", "part-time", "onsite", 3_000_000, 4_500_000,
   ["Organization", "Spreadsheets", "Communication"],
   "Expired vacancy for testing the employer's status filters.", :expired}
]

results =
  for {name, location, industry, type, mode, minimum, maximum, skills, description, stage} <-
        definitions do
    title = "#{name} [Demo]"
    status = if stage in [:draft, :expired], do: Atom.to_string(stage), else: "active"

    job =
      case Job
           |> Ash.Query.filter(organization_id == ^organization.id and title == ^title)
           |> Ash.read_one!(authorize?: false) do
        nil ->
          Job
          |> Ash.Changeset.for_create(:create, %{
            title: title,
            location: location,
            industry: industry,
            employment_type: type,
            work_mode: mode,
            salary_min: minimum,
            salary_max: maximum,
            currency: "IDR",
            status: status,
            requirements: skills,
            highlights: [
              "Work with a collaborative team",
              "Share progress and learn through feedback"
            ],
            description:
              "#{description}\n\nFictional vacancy for local manual testing. Salary is a sample monthly IDR range; this is not a real job opening."
          })
          |> Ash.Changeset.force_change_attributes(%{
            organization_id: organization.id,
            created_by: employer.id,
            synthetic: true,
            posted_at: if(status != "draft", do: DateTime.utc_now())
          })
          |> Ash.create!(authorize?: false)

        existing ->
          unless existing.synthetic and existing.created_by == employer.id,
            do: raise("Existing vacancy does not match the manual demo: #{title}")

          existing
      end

    application =
      if is_binary(stage) do
        case Repo.get_by(JosjobJob.Application, job_id: job.id, candidate_id: candidate.id) do
          nil ->
            {:ok, submitted} =
              Applications.submit(candidate, job.id, %{
                "consent" => true,
                "cover_letter" =>
                  "I would like to explore this role. This is a fictional application for manual testing."
              })

            {:ok, _} =
              JosjobRt.Chat.send_message(candidate, "application", submitted.id, %{
                "body" => "Hello! I would love to learn more about this role. [Demo]",
                "client_id" => "manual-demo-candidate-#{job.id}"
              })

            {:ok, _} =
              JosjobRt.Chat.send_message(employer, "application", submitted.id, %{
                "body" =>
                  "Thanks for applying. We will share updates here. You can test this conversation from both accounts. [Demo]",
                "client_id" => "manual-demo-employer-#{job.id}"
              })

            targets =
              ~w(applied reviewing interview offer hired)
              |> Enum.take_while(&(&1 != stage))
              |> Enum.drop(1)

            targets = targets ++ if(stage == "applied", do: [], else: [stage])

            Enum.reduce(targets, submitted, fn target, current ->
              {:ok, updated} =
                Applications.advance(employer, current.id, %{
                  "status" => target,
                  "expected_status" => current.status,
                  "note" =>
                    "Demo hiring update: #{target}. This note is shared with the candidate.",
                  "interview_at" =>
                    if(target == "interview",
                      do:
                        DateTime.utc_now()
                        |> DateTime.add(2 * 86_400, :second)
                        |> DateTime.to_iso8601()
                    )
                })

              updated
            end)

          existing ->
            existing
        end
      end

    %{
      title: job.title,
      id: job.id,
      status: job.status,
      application_status: application && application.status
    }
  end

IO.puts(
  Jason.encode!(
    %{
      organization: organization.name,
      organization_id: organization.id,
      employer: to_string(employer.email),
      candidate: to_string(candidate.email),
      vacancies: results
    },
    pretty: true
  )
)
