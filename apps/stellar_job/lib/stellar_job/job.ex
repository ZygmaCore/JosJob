defmodule StellarJob.Job do
  @moduledoc "Employer-owned listing; authorization is enforced by StellarJob.Listings."
  use Ash.Resource,
    otp_app: :stellar_job,
    domain: StellarJob,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("jobs")
    repo(Stellar.Repo)

    references do
      reference(:organization, on_delete: :delete)
      reference(:creator, on_delete: :nilify)
    end

    custom_indexes do
      index([:organization_id, :status, :posted_at],
        name: "jobs_organization_id_status_posted_at_index"
      )
    end

    check_constraints do
      check_constraint([:salary_min, :salary_max], "jobs_salary_range",
        check:
          "(salary_min IS NULL OR salary_min BETWEEN 0 AND 1000000000000) AND (salary_max IS NULL OR salary_max BETWEEN 0 AND 1000000000000) AND (salary_min IS NULL OR salary_max IS NULL OR salary_max >= salary_min)"
      )

      check_constraint(:status, "jobs_status", check: "status IN ('draft', 'active', 'expired')")

      check_constraint(:employment_type, "jobs_employment_type",
        check:
          "employment_type IN ('full-time', 'part-time', 'internship', 'contract', 'freelance')"
      )

      check_constraint(:work_mode, "jobs_work_mode",
        check: "work_mode IN ('remote', 'hybrid', 'onsite')"
      )
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:title, :string,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 160],
      public?: true
    )

    attribute(:description, :string,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 20_000],
      public?: true
    )

    attribute(:location, :string,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 160],
      public?: true
    )

    attribute(:industry, :string,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 120],
      public?: true
    )

    attribute(:employment_type, :string, allow_nil?: false, public?: true)
    attribute(:work_mode, :string, allow_nil?: false, public?: true)

    attribute(:requirements, {:array, :string},
      allow_nil?: false,
      default: [],
      constraints: [max_length: 40, items: [min_length: 1, max_length: 160]],
      public?: true
    )

    attribute(:highlights, {:array, :string},
      allow_nil?: false,
      default: [],
      constraints: [max_length: 20, items: [min_length: 1, max_length: 300]],
      public?: true
    )

    attribute(:salary_min, :integer, constraints: [min: 0, max: 1_000_000_000_000], public?: true)
    attribute(:salary_max, :integer, constraints: [min: 0, max: 1_000_000_000_000], public?: true)

    attribute(:currency, :string,
      allow_nil?: false,
      default: "IDR",
      constraints: [match: ~r/^[A-Z]{3}$/],
      public?: true
    )

    attribute(:status, :string, allow_nil?: false, default: "draft", public?: true)
    attribute(:synthetic, :boolean, allow_nil?: false, default: false, public?: true)
    attribute(:posted_at, :utc_datetime_usec, public?: true)
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :creator, Stellar.Accounts.User do
      attribute_type(:uuid)
      source_attribute(:created_by)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    default_accept([
      :title,
      :description,
      :location,
      :industry,
      :employment_type,
      :work_mode,
      :requirements,
      :highlights,
      :salary_min,
      :salary_max,
      :currency,
      :status
    ])
  end

  validations do
    validate(
      one_of(:employment_type, ["full-time", "part-time", "internship", "contract", "freelance"])
    )

    validate(one_of(:work_mode, ["remote", "hybrid", "onsite"]))
    validate(one_of(:status, ["draft", "active", "expired"]))
    validate(compare(:salary_max, greater_than_or_equal_to: :salary_min))
  end
end
