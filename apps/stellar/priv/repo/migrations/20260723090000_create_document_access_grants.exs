defmodule Stellar.Repo.Migrations.CreateDocumentAccessGrants do
  @moduledoc """
  Grant akses per-user ke `Document` (share ala Google Docs). Satu baris per
  (document, user); `allow` + rentang `valid_from`/`valid_until` menentukan aktif.

  Hand-authored mengikuti pola `create_documents` (repo Stellar.Repo). Jalankan
  `mix ash.codegen` di lingkungan Elixir yang sehat untuk merekonsiliasi snapshot.
  """

  use Ecto.Migration

  def up do
    create table(:document_access_grants, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :allow, :boolean, null: false, default: true
      add :valid_from, :utc_datetime_usec
      add :valid_until, :utc_datetime_usec
      add :granted_by_id, :uuid

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :document_id,
          references(:documents,
            column: :id,
            name: "document_access_grants_document_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "document_access_grants_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create unique_index(:document_access_grants, [:document_id, :user_id],
             name: "document_access_grants_unique_document_user_index"
           )
  end

  def down do
    drop_if_exists unique_index(:document_access_grants, [:document_id, :user_id],
                     name: "document_access_grants_unique_document_user_index"
                   )

    drop constraint(:document_access_grants, "document_access_grants_document_id_fkey")

    drop constraint(:document_access_grants, "document_access_grants_user_id_fkey")

    drop table(:document_access_grants)
  end
end
