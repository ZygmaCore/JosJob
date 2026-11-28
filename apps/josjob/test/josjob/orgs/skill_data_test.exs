defmodule Josjob.Orgs.SkillDataTest do
  @moduledoc "SkillData ↔ IndustryData consistency + skill→industry linkage/filter."
  use Josjob.DataCase, async: false

  require Ash.Query

  alias Josjob.Orgs.{Industry, IndustryData, Skill, SkillData}

  test "every by_industry key is a known IndustryData industry" do
    known = MapSet.new(IndustryData.all())

    for name <- Map.keys(SkillData.by_industry()) do
      assert MapSet.member?(known, name),
             "SkillData.by_industry key #{inspect(name)} is not in IndustryData.all/0 — " <>
               "seed_skills would leave its skills with industry_id = nil"
    end
  end

  test "skill names are unique across general + per-industry (skills.unique_name)" do
    all = SkillData.all()
    dupes = all -- Enum.uniq(all)

    assert dupes == [],
           "duplicate skill names would violate skills.unique_name: #{inspect(dupes)}"
  end

  test "seeded skills link to their industry and filter by industry_id" do
    {:ok, healthcare} =
      Industry
      |> Ash.Changeset.for_create(:create, %{name: "Healthcare"})
      |> Ash.create(authorize?: false)

    {:ok, _} =
      Skill
      |> Ash.Changeset.for_create(:create, %{name: "Patient Care", industry_id: healthcare.id})
      |> Ash.create(authorize?: false)

    {:ok, general} =
      Skill
      |> Ash.Changeset.for_create(:create, %{name: "Communication"})
      |> Ash.create(authorize?: false)

    # General skills carry no industry -> always suggested in onboarding.
    assert is_nil(general.industry_id)

    # The /api/skills?industry_id= filter (SkillController) returns only the
    # industry's own skills.
    names =
      Skill
      |> Ash.Query.filter(industry_id == ^healthcare.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.name)

    assert names == ["Patient Care"]
  end
end
