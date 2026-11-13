defmodule Josjob.Rbac.RolePermission do
  @moduledoc "Join role ↔ permission (role punya izin apa)."
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Rbac

  postgres do
    table("role_permissions")
    repo(Josjob.Repo)
  end

  relationships do
    belongs_to :role, Josjob.Rbac.Role do
      allow_nil?(false)
      primary_key?(true)
      public?(true)
    end

    belongs_to :permission, Josjob.Rbac.Permission do
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
