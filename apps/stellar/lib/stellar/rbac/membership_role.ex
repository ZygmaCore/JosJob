defmodule Stellar.Rbac.MembershipRole do
  @moduledoc "Join membership ↔ role (role user DI org tsb)."
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Rbac

  postgres do
    table("membership_roles")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Audit trail: id user pembuat & pengubah terakhir (diisi otomatis dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)
  end

  relationships do
    belongs_to :membership, Stellar.Orgs.Membership do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :role, Stellar.Rbac.Role do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_membership_role, [:membership_id, :role_id])
  end

  changes do
    change(Stellar.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:membership_id, :role_id])
  end
end
