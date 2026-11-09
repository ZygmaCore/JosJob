defmodule StellarWeb.Api.ProfessionController do
  @moduledoc "API publik: daftar profesi (master data). Default urut A-Z by name."
  use StellarWeb, :controller

  alias Stellar.Orgs.Profession

  # GET /api/professions -> { data: [ {id, name}, ... ] } (urut name asc)
  def index(conn, _params) do
    professions = Profession |> Ash.Query.sort(name: :asc) |> Ash.read!(authorize?: false)

    json(conn, %{
      data: Enum.map(professions, &%{id: &1.id, name: &1.name})
    })
  end
end
