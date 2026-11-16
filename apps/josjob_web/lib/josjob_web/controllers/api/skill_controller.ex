defmodule JosjobWeb.Api.SkillController do
  @moduledoc """
  API publik: daftar skill (master data). Default urut A-Z by name.
  Filter opsional `?industry_id=<uuid>` untuk skill pada industri tertentu.
  """
  use JosjobWeb, :controller

  require Ash.Query
  alias Josjob.Orgs.Skill

  # GET /api/skills[?industry_id=uuid] -> { data: [ {id, name, industry_id, industry} ] }
  def index(conn, params) do
    query = Ash.Query.sort(Skill, name: :asc)

    query =
      case params["industry_id"] do
        id when is_binary(id) and id != "" -> Ash.Query.filter(query, industry_id == ^id)
        _ -> query
      end

    skills = query |> Ash.read!(authorize?: false) |> Ash.load!(:industry)
    json(conn, %{data: Enum.map(skills, &skill_json/1)})
  end

  defp skill_json(s) do
    %{
      id: s.id,
      name: s.name,
      industry_id: s.industry_id,
      industry: s.industry && %{id: s.industry.id, name: s.industry.name}
    }
  end
end
