defmodule Josjob.Repo.Migrations.AddCandidateCvProfiles do
  use Ecto.Migration

  def change do
    create table(:candidate_cv_profiles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :headline, :text
      add :summary, :text
      add :resume_document_id, references(:documents, type: :uuid, on_delete: :nilify_all)
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create unique_index(:candidate_cv_profiles, [:user_id],
             name: :candidate_cv_profiles_unique_cv_user_index
           )
  end
end
