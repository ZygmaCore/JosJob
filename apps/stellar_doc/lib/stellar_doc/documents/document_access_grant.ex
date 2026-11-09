defmodule StellarDoc.Documents.DocumentAccessGrant do
  @moduledoc """
  Izin akses per-user ke sebuah `Document` — model *share* ala Google Docs:
  pemilik (uploader) menentukan siapa yang boleh mengakses dokumennya.

  Satu baris = satu pasangan `(document, user)`:

    * `allow`      → nyalakan/matikan akses tanpa menghapus baris.
    * `valid_from` → mulai berlaku (null = langsung aktif).
    * `valid_until`→ kedaluwarsa (null = tak dibatasi). "Masa berlaku" yang
                     bisa dikonfigurasi (requirement work-item).

  Grant dianggap **aktif** bila `allow` true DAN `now` ada di dalam rentang
  `valid_from..valid_until`. Enforcement dilakukan lewat query-scope
  (`StellarDoc.Documents.visible_to/1` + helper), bukan Ash policy — konsisten
  dengan resource `Document`.
  """
  use Ash.Resource,
    otp_app: :stellar_doc,
    data_layer: AshPostgres.DataLayer,
    domain: StellarDoc.Documents

  postgres do
    table("document_access_grants")
    repo(Stellar.Repo)

    references do
      reference(:document, on_delete: :delete)
      reference(:user, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Aktif/nonaktif tanpa menghapus baris (bisa dinyalakan lagi).
    attribute(:allow, :boolean, allow_nil?: false, default: true, public?: true)

    # Rentang berlaku (null = tak dibatasi di sisi itu).
    attribute(:valid_from, :utc_datetime_usec, public?: true)
    attribute(:valid_until, :utc_datetime_usec, public?: true)

    # Siapa yang memberi akses (pemilik/pengelola). Audit; tanpa FK.
    attribute(:granted_by_id, :uuid, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :document, StellarDoc.Documents.Document do
      allow_nil?(false)
      public?(true)
    end

    # Penerima akses.
    belongs_to :user, Stellar.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    # Satu grant per (dokumen, user) — berbagi ulang = perbarui baris yang ada.
    identity(:unique_document_user, [:document_id, :user_id])
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    default_accept([
      :allow,
      :valid_from,
      :valid_until,
      :granted_by_id,
      :document_id,
      :user_id
    ])

    # Upsert by (document, user): share ulang ke user yang sama memperbarui
    # flag/masa-berlaku alih-alih menolak (unique identity).
    create :upsert do
      upsert?(true)
      upsert_identity(:unique_document_user)
      upsert_fields([:allow, :valid_from, :valid_until, :granted_by_id])
      accept([:allow, :valid_from, :valid_until, :granted_by_id, :document_id, :user_id])
    end
  end
end
