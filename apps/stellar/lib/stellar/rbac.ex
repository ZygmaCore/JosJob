defmodule Stellar.Rbac do
  @moduledoc "Domain RBAC data-driven: permissions, roles, dan join-nya."
  use Ash.Domain

  resources do
    resource(Stellar.Rbac.Permission)
    resource(Stellar.Rbac.Role)
    resource(Stellar.Rbac.RolePermission)
    resource(Stellar.Rbac.MembershipRole)
  end
end
