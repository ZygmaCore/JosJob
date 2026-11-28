defmodule JosjobRag.CategoryRankingTest do
  use ExUnit.Case, async: true
  alias JosjobRag.CategoryRanking

  @now ~U[2026-11-23 00:00:00Z]

  test "extracts multiple CV categories from structured facts and reuses an unchanged profile" do
    cv = %{"skills" => ["Elixir", "Figma"], "experience" => [%{"title" => "Backend Developer"}]}
    profile = CategoryRanking.profile(cv)
    assert profile["categories"] == ["backend", "design"]
    assert CategoryRanking.profile(Map.put(cv, "matching_profile", profile)) == profile

    changed = Map.put(cv, "skills", ["Accounting"])
    updated = CategoryRanking.profile(Map.put(changed, "matching_profile", profile))
    refute updated["content_hash"] == profile["content_hash"]
    assert "finance" in updated["categories"]
  end

  test "category then skill overlap precede recency; unrelated jobs stay visible" do
    jobs = [
      %{id: "new-unrelated", title: "Accountant", requirements: ["Accounting"], posted_at: @now},
      %{
        id: "related",
        title: "Frontend Developer",
        requirements: ["React", "Git"],
        posted_at: @now
      },
      %{
        id: "partial",
        title: "Backend Developer",
        requirements: ["Elixir", "Rust"],
        posted_at: @now
      },
      %{
        id: "best",
        title: "Backend Developer",
        requirements: ["Elixir", "Postgres"],
        posted_at: DateTime.add(@now, -60 * 86_400)
      }
    ]

    ranked = CategoryRanking.rank(%{skills: ["Elixir", "PostgreSQL", "Git"]}, jobs, now: @now)
    assert Enum.map(ranked, & &1.job_id) == ["best", "partial", "related", "new-unrelated"]
    assert hd(ranked).missing_skills == []
    assert List.last(ranked).relevance_label == "Less relevant"
    assert List.last(ranked).missing_skills == []
    assert List.last(ranked).skill_score == nil
    assert Enum.all?(ranked, &is_nil(&1.semantic_score))
  end

  test "unknown categories use exact skills without treating Java as JavaScript" do
    [matched, missing] =
      CategoryRanking.rank(%{skills: ["Specialized Tool"]}, [
        %{id: "b", title: "Specialist", requirements: ["Other Tool"]},
        %{id: "a", title: "Specialist", requirements: ["Specialized Tool"]}
      ])

    assert matched.job_id == "a"
    assert missing.skill_score == 0.0

    [job] =
      CategoryRanking.rank(%{skills: ["Java"]}, [
        %{id: "js", title: "Backend Developer", requirements: ["JavaScript"]}
      ])

    assert job.matched_skills == []
  end

  test "job title determines its category even when a shared skill suggests another role" do
    assert CategoryRanking.categories(%{title: "Data Analyst", requirements: ["Elixir", "SQL"]}) ==
             ["data"]

    assert CategoryRanking.profile(%{skills: ["Communication", "Git", "SQL"]})["categories"] == []
  end
end
