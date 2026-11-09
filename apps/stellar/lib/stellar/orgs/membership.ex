defmodule Stellar.Orgs.Membership do
  @moduledoc "Keanggotaan user di sebuah organisasi (inti multi-tenant)."
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Orgs

  postgres do
    table("memberships")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :status, :atom do
      constraints(one_of: [:invited, :active, :suspended])
      default(:active)
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)

    # Audit trail: id user pembuat & pengubah terakhir (diisi otomatis dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)
  end

  relationships do
    belongs_to :user, Stellar.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_user_org, [:user_id, :organization_id])
  end

  changes do
    change(Stellar.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:status, :user_id, :organization_id])
  end
end
