defmodule StellarWeb.Api.IndustryController do
  @moduledoc "API publik: daftar industri (data referensi). Default urut A-Z by name."
  use StellarWeb, :controller

  alias Stellar.Orgs.Industry

  # GET /api/industries -> { data: [ {id, name, parent_id, parent} ] }
  def index(conn, _params) do
    industries =
      Industry
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(authorize?: false)
      |> Ash.load!(:parent)

    json(conn, %{data: Enum.map(industries, &industry_json/1)})
  end

  defp industry_json(i) do
    %{
      id: i.id,
      name: i.name,
      parent_id: i.parent_id,
      parent: i.parent && %{id: i.parent.id, name: i.parent.name}
    }
  end
end
