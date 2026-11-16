defmodule JosjobWeb.Api.CountryController do
  @moduledoc "API publik: daftar negara (master data). Default urut A-Z by name."
  use JosjobWeb, :controller

  alias Josjob.Orgs.Country

  # GET /api/countries -> { data: [ {id, name, code, phone_code}, ... ] } (urut name asc)
  def index(conn, _params) do
    countries = Country |> Ash.Query.sort(name: :asc) |> Ash.read!(authorize?: false)

    json(conn, %{
      data:
        Enum.map(
          countries,
          &%{id: &1.id, name: &1.name, code: &1.code, phone_code: &1.phone_code}
        )
    })
  end
end
