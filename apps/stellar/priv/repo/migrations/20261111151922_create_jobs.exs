defmodule Stellar.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all),
        null: false

      add :created_by, references(:users, type: :uuid, on_delete: :nilify_all)
      add :title, :text, null: false
      add :description, :text, null: false
      add :location, :text, null: false
      add :industry, :text, null: false
      add :employment_type, :text, null: false
      add :work_mode, :text, null: false
      add :requirements, {:array, :text}, null: false, default: []
      add :highlights, {:array, :text}, null: false, default: []
      add :salary_min, :bigint
      add :salary_max, :bigint
      add :currency, :text, null: false, default: "IDR"
      add :status, :text, null: false, default: "draft"
      add :synthetic, :boolean, null: false, default: false
      add :posted_at, :utc_datetime_usec

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:jobs, [:organization_id, :status, :posted_at])

    create constraint(:jobs, :jobs_salary_range,
             check:
               "(salary_min IS NULL OR salary_min BETWEEN 0 AND 1000000000000) AND (salary_max IS NULL OR salary_max BETWEEN 0 AND 1000000000000) AND (salary_min IS NULL OR salary_max IS NULL OR salary_max >= salary_min)"
           )

    create constraint(:jobs, :jobs_status, check: "status IN ('draft', 'active', 'expired')")

    create constraint(:jobs, :jobs_employment_type,
             check:
               "employment_type IN ('full-time', 'part-time', 'internship', 'contract', 'freelance')"
           )

    create constraint(:jobs, :jobs_work_mode,
             check: "work_mode IN ('remote', 'hybrid', 'onsite')"
           )
  end
end
