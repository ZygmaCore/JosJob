defmodule StellarWeb.Api.Admin.OrganizationController do
  @moduledoc """
  Daftar organisasi untuk **superuser** (Bearer + `RequireSuperuserApi`) — dipakai
  form undangan teacher (dropdown pilih org). `GET /api/admin/organizations`.
  """
  use StellarWeb, :controller

  require Ash.Query
  alias Stellar.Orgs.Organization

  def index(conn, _params) do
    orgs =
      Organization
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&%{id: &1.id, name: &1.name})

    json(conn, %{data: orgs})
  end
end
