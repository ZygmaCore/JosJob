defmodule Josjob.Accounts.Profile do
  @moduledoc "Snapshot jawaban onboarding per user (1:1, jsonb). Disinkron offline-first (LWW)."
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Accounts

  postgres do
    table("profiles")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Kumpulan jawaban onboarding (bebas bentuk) -> jsonb.
    attribute(:answers, :map, public?: true, default: %{})
    # Timestamp versi dari KLIEN (untuk last-write-wins).
    attribute(:answers_updated_at, :utc_datetime_usec, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, Josjob.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    # 1:1 dengan user.
    identity(:unique_user, [:user_id])
  end

  actions do
    defaults([:read, :update, :destroy])
    default_accept([:answers, :answers_updated_at, :user_id])

    # Upsert by user_id -> PUT jalan baik row sudah ada maupun belum.
    # LWW ditentukan di controller (bandingkan answers_updated_at klien vs tersimpan)
    # sebelum memanggil aksi ini; replay payload sama = idempotent.
    create :upsert_answers do
      accept([:user_id, :answers, :answers_updated_at])
      upsert?(true)
      upsert_identity(:unique_user)
    end
  end
end
