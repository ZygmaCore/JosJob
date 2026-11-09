defmodule StellarDoc.Documents.Document do
  @moduledoc """
  Dokumen (bank dokumen) — polymorphic lewat `course_id`:

    * `course_id` terisi → **course_document**
    * `course_id` null   → **user_document**

  URL-only (belum ada upload file). `user_id` = pengunggah/pemilik;
  `organization_id` = tenant (untuk visibilitas). `course_id` = uuid lepas
  (tanpa FK, independen dari modul lain).
  """
  use Ash.Resource,
    otp_app: :stellar_doc,
    data_layer: AshPostgres.DataLayer,
    domain: StellarDoc.Documents

  postgres do
    table("documents")
    repo(Stellar.Repo)

    references do
      reference(:user, on_delete: :delete)
      reference(:organization, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:url, :string, allow_nil?: false, public?: true)
    # Mimetype dokumen, mis. "application/pdf", "video/mp4". Bukan enum kategori.
    attribute(:mime_type, :string, public?: true)
    attribute(:description, :string, public?: true)
    # Penanda kepemilikan: terisi = course_document; null = user_document. Tanpa FK.
    attribute(:course_id, :uuid, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # Pengunggah = pemilik.
    belongs_to :user, Stellar.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    # Tenant pemilik dokumen (scope visibilitas).
    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    default_accept([
      :title,
      :url,
      :mime_type,
      :description,
      :course_id,
      :user_id,
      :organization_id
    ])
  end
end
