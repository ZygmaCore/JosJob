defmodule JosjobWeb.Api.StudentScope do
  @moduledoc "Org ids tempat user jadi member aktif (scoping API student)."
  require Ash.Query
  alias Josjob.Orgs.Membership

  def org_ids(user) do
    Membership
    |> Ash.Query.filter(user_id == ^user.id and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.organization_id)
    |> Enum.uniq()
  end
end
