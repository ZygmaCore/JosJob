defmodule Stellar.Rbac.RolePermission do
  @moduledoc "Join role ↔ permission (role punya izin apa)."
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Rbac

  postgres do
    table("role_permissions")
    repo(Stellar.Repo)
  end

  relationships do
    belongs_to :role, Stellar.Rbac.Role do
      allow_nil?(false)
      primary_key?(true)
      public?(true)
    end

    belongs_to :permission, Stellar.Rbac.Permission do
      allow_nil?(false)
      primary_key?(true)
      public?(true)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:role_id, :permission_id])
  end
end
