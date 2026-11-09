defmodule StellarLrn.Seeds do
  @moduledoc """
  Sample catalog seeder (idempotent): Sections → Courses → Classes for the
  initial "Atveti" org, so the student catalog (`GET /api/catalog/courses`) and
  the Explore page have real data out of the box.

  Lives in `:stellar_lrn` (which depends on `:stellar`) so it can reference BOTH
  the learning resources AND `Stellar.Orgs`/`Stellar.Accounts`. It is invoked
  from `Stellar.Release.seed/0` via runtime dispatch (`apply/3`) — `:stellar`
  must NOT reference `:stellar_lrn` at compile time or the umbrella forms a
  dependency cycle.

  Visibility note: the catalog is scoped to the orgs where the caller is an
  ACTIVE member, so this also ensures the Atveti owner (the seeded superuser)
  has an active membership — otherwise the seeded courses would be invisible to
  everyone.
  """
  require Ash.Query

  alias Stellar.Orgs.{Organization, Industry, Membership}

  alias StellarLrn.Learning.{
    Section,
    Course,
    Class,
    SectionOrganization,
    CourseOrganization,
    CourseIndustry
  }

  # Sections (categories) → their courses. Each course = {title, description,
  # [industry names (must match Stellar.Orgs.IndustryData)], price_cents}.
  # price_cents nil = FREE (one-tap enrol); > 0 = PAID (Stripe card). A couple
  # are priced so both flows can be exercised out of the box (currency: usd).
  @catalog [
    {"Hospitality & Tourism",
     [
       {"Food Safety & Hygiene Essentials",
        "Master safe food handling, storage and hygiene so you keep customers safe and your venue compliant.",
        ["Hospitality & Tourism"], nil},
       {"Front Office & Guest Service Excellence",
        "Deliver polished, memorable guest experiences from check-in to check-out.",
        ["Hospitality & Tourism", "Retail & Sales"], 4900}
     ]},
    {"Construction & Trades",
     [
       {"Work Health & Safety White Card",
        "The mandatory safety induction every worker needs before stepping onto a construction site.",
        ["Construction & Trades"], nil},
       {"Working Safely at Heights",
        "Work confidently at height with the right equipment, checks and fall-protection systems.",
        ["Construction & Trades"], nil}
     ]},
    {"Health & Community",
     [
       {"Infection Prevention & Control",
        "Build the infection-control habits that protect vulnerable people in care and support settings.",
        ["Healthcare"], nil},
       {"Aged Care Support Foundations",
        "Start your aged-care career with person-centred support skills and wellbeing essentials.",
        ["Healthcare"], 9900}
     ]},
    {"Business & Technology",
     [
       {"Workplace Communication Skills",
        "Communicate clearly and confidently with colleagues, managers and customers.",
        ["Retail & Sales"], nil},
       {"Introduction to IT Support",
        "Get job-ready for a help-desk role: troubleshooting, hardware basics and great service.",
        ["Software & IT"], nil}
     ]}
  ]

  # A sample schedule + capacity for the one class seeded per course.
  @schedule [%{"date" => "2026-08-05", "start" => "09:00", "end" => "11:00"}]
  @capacity 25

  @doc """
  Seed the sample catalog into the "Atveti" org. Idempotent: re-running finds
  existing rows by natural key instead of duplicating. Returns the number of
  courses ensured (0 if the Atveti org does not exist yet).
  """
  def seed do
    {:ok, _} = Application.ensure_all_started(:stellar_lrn)

    case atveti() do
      nil ->
        IO.puts("StellarLrn.Seeds: org \"Atveti\" belum ada — lewati seed katalog.")
        0

      %Organization{} = org ->
        instructor_id = org.user_id
        ensure_membership(org.id, instructor_id)

        for {section_name, courses} <- @catalog, reduce: 0 do
          acc ->
            section = get_or_create_section(section_name)
            link_section_org(section.id, org.id)

            Enum.each(courses, fn {title, desc, industries, price_cents} ->
              course = get_or_create_course(title, desc, section.id, price_cents)
              link_course_org(course.id, org.id)
              Enum.each(industries, &link_course_industry(course.id, &1))
              get_or_create_class(title, course.id, org.id, instructor_id)
            end)

            acc + length(courses)
        end
    end
  end

  # ---- lookups -----------------------------------------------------------

  defp atveti do
    Organization
    |> Ash.Query.filter(name == "Atveti")
    |> one()
  end

  defp find_industry(name) do
    Industry
    |> Ash.Query.filter(name == ^name)
    |> one()
  end

  # First matching row (or nil). Section/Course/Class have no unique constraint,
  # and even org/industry names could be duplicated by admin CRUD — so we take
  # the first match instead of `read_one!`, which would RAISE on a duplicate and
  # abort the whole (idempotent) deploy seed.
  defp one(query), do: query |> Ash.read!(authorize?: false) |> List.first()

  # ---- get-or-create (Section/Course/Class have no unique identity) -------

  defp get_or_create_section(name) do
    existing =
      Section
      |> Ash.Query.filter(name == ^name)
      |> one()

    existing ||
      Section
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create!(authorize?: false)
  end

  defp get_or_create_course(title, description, section_id, price_cents) do
    # Scope by section too: a bare title match could pick up another tenant's
    # identically-titled course and silently link Atveti to it.
    existing =
      Course
      |> Ash.Query.filter(title == ^title and section_id == ^section_id)
      |> one()

    case existing do
      nil ->
        Course
        |> Ash.Changeset.for_create(:create, %{
          title: title,
          description: description,
          is_active: true,
          # Sample courses are public so individual learners (no org) see them.
          is_public: true,
          price_cents: price_cents,
          currency: "usd",
          section_id: section_id
        })
        |> Ash.create!(authorize?: false)

      # Re-seed: keep the sample's public flag + price authoritative (also
      # back-fills rows seeded before is_public/price_cents existed).
      %Course{} = course ->
        course
        |> Ash.Changeset.for_update(:update, %{is_public: true, price_cents: price_cents})
        |> Ash.update!(authorize?: false)
    end
  end

  defp get_or_create_class(title, course_id, org_id, instructor_id) do
    existing =
      Class
      |> Ash.Query.filter(title == ^title and course_id == ^course_id)
      |> one()

    existing ||
      Class
      |> Ash.Changeset.for_create(:create, %{
        title: title,
        schedule: @schedule,
        capacity: @capacity,
        course_id: course_id,
        organization_id: org_id,
        instructor_id: instructor_id
      })
      |> Ash.create!(authorize?: false)
  end

  # ---- joins + membership (idempotent via upsert on unique identity) ------

  defp ensure_membership(org_id, user_id) do
    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: user_id,
      organization_id: org_id,
      status: :active
    })
    |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_user_org)
  end

  defp link_section_org(section_id, org_id) do
    SectionOrganization
    |> Ash.Changeset.for_create(:create, %{section_id: section_id, organization_id: org_id})
    |> Ash.create!(
      authorize?: false,
      upsert?: true,
      upsert_identity: :unique_section_organization
    )
  end

  defp link_course_org(course_id, org_id) do
    CourseOrganization
    |> Ash.Changeset.for_create(:create, %{course_id: course_id, organization_id: org_id})
    |> Ash.create!(
      authorize?: false,
      upsert?: true,
      upsert_identity: :unique_course_organization
    )
  end

  defp link_course_industry(course_id, industry_name) do
    case find_industry(industry_name) do
      nil ->
        :noop

      %Industry{id: industry_id} ->
        CourseIndustry
        |> Ash.Changeset.for_create(:create, %{course_id: course_id, industry_id: industry_id})
        |> Ash.create!(
          authorize?: false,
          upsert?: true,
          upsert_identity: :unique_course_industry
        )
    end
  end
end
