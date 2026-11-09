defmodule Stellar.Accounts.UserDetail do
  @moduledoc """
  Profil terstruktur user (1:1). Menyimpan hasil onboarding worker/graduate ke
  field ber-skema (JSON schema via embedded resources, lihat
  `Stellar.Accounts.Onboarding.*`):

    * `resume`   -> riwayat kerja + skill
    * `education`-> pendidikan formal + achievement/sertifikasi
    * `interest` -> hobi + industri/profesi/negara lain

  Diisi dari payload onboarding oleh `Stellar.Accounts.Onboarding.Sync`.
  `organization` info akun organisasi disimpan RELASIONAL di
  `Stellar.Orgs.Organization`, bukan di sini.
  """
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Accounts

  postgres do
    table("user_details")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:resume, Stellar.Accounts.Onboarding.Resume, public?: true)
    attribute(:education, Stellar.Accounts.Onboarding.Education, public?: true)
    attribute(:interest, Stellar.Accounts.Onboarding.Interest, public?: true)

    # Field lama (jsonb bebas). `organization` kini relasional (Orgs.Organization);
    # disimpan di sini hanya untuk kompatibilitas mundur.
    attribute(:organization, :map, public?: true)
    attribute(:training_offers, :map, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, Stellar.Accounts.User do
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

    default_accept([
      :resume,
      :education,
      :interest,
      :organization,
      :training_offers,
      :user_id
    ])

    # Upsert by user_id -> jalan baik row sudah ada maupun belum. Dipakai
    # `Onboarding.Sync` untuk memproyeksikan jawaban onboarding ke field ber-skema.
    create :upsert_details do
      accept([:user_id, :resume, :education, :interest])
      upsert?(true)
      upsert_identity(:unique_user)
    end
  end
end
