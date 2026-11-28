defmodule JosjobWeb.JobSkillSeedsTest do
  use JosjobWeb.ConnCase, async: false
  require Ash.Query
  import JosjobWeb.JobFixtures

  alias JosjobLrn.JobSkillSeeds
  alias JosjobLrn.Learning.{Class, Course}
  alias JosjobRag.{Ranker, Text}

  test "course seeds cover active demo job tags, open for unaffiliated candidates and preserve edits",
       c do
    owner = user!()
    org = organization!(owner)
    candidate = user!()
    {:ok, first} = JobSkillSeeds.seed(organization_id: org.id)
    assert first.courses == 20
    assert first.created_courses == 20
    courses = Ash.read!(Course, load: [:classes], authorize?: false)

    requirements =
      JosjobRag.DemoSeeds.manifest()["jobs"]
      |> Enum.filter(&(&1["status"] == "active"))
      |> Enum.flat_map(& &1["requirements"])
      |> Enum.uniq()

    assert requirements != []
    recommendations = Ranker.recommend_courses(requirements, courses)
    covered = Enum.flat_map(recommendations, & &1.matched_skills)

    assert Enum.all?(requirements, fn skill ->
             Enum.any?(covered, &Text.same_skill?(&1, skill))
           end)

    catalog = c.conn |> auth(candidate) |> get(~p"/api/catalog/courses") |> json_response(200)
    assert length(catalog["data"]) == 20

    assert Enum.all?(
             catalog["data"],
             &(&1["is_free"] and &1["has_curriculum"] and &1["skill_tags"] != [])
           )

    [course | _] = courses
    assert course.description =~ "Introductory self-paced mini-course"
    assert first.lessons == 60

    study =
      c.conn
      |> auth(candidate)
      |> post(~p"/api/catalog/courses/#{course.id}/study/enroll", %{})
      |> json_response(200)

    assert study["data"]["enrolled"]
    assert study["data"]["lesson_count"] == 3

    course
    |> Ash.Changeset.for_update(:update, %{
      description: "Edited course",
      skill_tags: ["Custom skill"],
      price_cents: 500
    })
    |> Ash.update!(authorize?: false)

    {:ok, second} = JobSkillSeeds.seed(organization_id: org.id)
    assert second.created_courses == 0
    assert second.course_ids == first.course_ids
    assert Ash.count!(Course, authorize?: false) == 20
    assert Ash.count!(Class, authorize?: false) == 0
    updated = Ash.get!(Course, course.id, authorize?: false)
    assert updated.description == "Edited course"
    assert updated.skill_tags == ["Custom skill"]
    assert updated.price_cents == 500
  end
end
