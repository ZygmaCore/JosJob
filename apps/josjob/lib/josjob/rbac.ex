defmodule Josjob.Rbac do
  @moduledoc "Domain RBAC data-driven: permissions, roles, dan join-nya."
  use Ash.Domain

  resources do
    resource(Josjob.Rbac.Permission)
    resource(Josjob.Rbac.Role)
    resource(Josjob.Rbac.RolePermission)
    resource(Josjob.Rbac.MembershipRole)
  end
end
