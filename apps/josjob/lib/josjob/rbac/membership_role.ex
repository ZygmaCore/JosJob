defmodule Josjob.Rbac.MembershipRole do
  @moduledoc "Join membership ↔ role (role user DI org tsb)."
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Rbac

  postgres do
    table("membership_roles")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Audit trail: id user pembuat & pengubah terakhir (diisi otomatis dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)
  end

  relationships do
    belongs_to :membership, Josjob.Orgs.Membership do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :role, Josjob.Rbac.Role do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_membership_role, [:membership_id, :role_id])
  end

  changes do
    change(Josjob.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:membership_id, :role_id])
  end
end
