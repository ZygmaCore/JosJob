defmodule Josjob.Repo.Migrations.AddLearnerCertificates do
  use Ecto.Migration

  def change do
    create table(:learner_certificates, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :title, :text, null: false
      add :issuer, :text, null: false
      add :issued_on, :date
      add :expires_on, :date
      add :credential_id, :text
      add :credential_url, :text
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:learner_certificates, [:user_id, :created_at])

    create constraint(:learner_certificates, :certificate_dates,
             check: "expires_on IS NULL OR issued_on IS NULL OR expires_on >= issued_on"
           )
  end
end
