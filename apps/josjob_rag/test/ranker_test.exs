defmodule JosjobRag.RankerTest do
  use ExUnit.Case, async: true

  alias JosjobRag.Ranker

  @now ~U[2026-11-18 00:00:00Z]

  defp job(id, attributes) do
    Map.merge(
      %{
        id: id,
        title: "Backend Engineer",
        description: "Build APIs",
        requirements: [],
        posted_at: @now
      },
      Map.new(attributes)
    )
  end

  describe "weights/0" do
    test "exposes the documented constants" do
      assert Ranker.weights() == %{
               semantic: 0.6,
               skill: 0.4,
               match: 0.85,
               recency: 0.15,
               recency_half_life_days: 30.0,
               unknown_recency: 0.5,
               course_skill: 0.7,
               course_semantic: 0.3
             }
    end
  end

  describe "recency_score/2" do
    test "has a 30-day half-life" do
      assert_in_delta Ranker.recency_score(DateTime.add(@now, -30, :day), @now), 0.5, 1.0e-9
      assert_in_delta Ranker.recency_score(DateTime.add(@now, -60, :day), @now), 0.25, 1.0e-9
    end

    test "a fresh posting scores 1.0 and a missing date scores 0.5" do
      assert Ranker.recency_score(@now, @now) == 1.0
      assert Ranker.recency_score(nil, @now) == 0.5
      assert Ranker.recency_score(:unknown, @now) == 0.5
    end

    test "future dates clamp to 1.0" do
      assert Ranker.recency_score(DateTime.add(@now, 10, :day), @now) == 1.0
    end
  end

  describe "match_score/2" do
    test "reweights when only one component exists" do
      assert Ranker.match_score(nil, 0.75) == 0.75
      assert Ranker.match_score(0.5, nil) == 0.5
      assert Ranker.match_score(nil, nil) == 0.0
    end

    test "uses 0.6 semantic + 0.4 skill" do
      assert Ranker.match_score(1.0, 0.0) == 0.6
      assert Ranker.match_score(0.0, 1.0) == 0.4
      assert_in_delta Ranker.match_score(0.5, 0.5), 0.5, 1.0e-9
    end
  end

  describe "score_job/3" do
    test "combines semantic, skill, and recency with an explanation" do
      item =
        Ranker.score_job(
          ["Go", "PostgreSQL"],
          job("job-1", requirements: ["Go", "PostgreSQL", "Kubernetes"]),
          semantic: 0.8,
          now: @now
        )

      assert item.job_id == "job-1"
      assert item.matched_skills == ["Go", "PostgreSQL"]
      assert item.missing_skills == ["Kubernetes"]
      assert_in_delta item.skill_score, 0.6667, 1.0e-4
      assert_in_delta item.match, 0.7467, 1.0e-4
      assert_in_delta item.match_score, 0.7847, 1.0e-4
      assert item.recency_score == 1.0
      assert item.explanation =~ "2 dari 3 skill terpenuhi"
      assert item.explanation =~ "Kubernetes"
    end

    test "falls back to skill overlap when semantic is missing" do
      item =
        Ranker.score_job(
          ["Go"],
          job("job-1", requirements: ["Go", "Rust"]),
          semantic: nil,
          now: @now
        )

      assert item.semantic_score == nil
      assert item.skill_score == 0.5
      assert item.match == 0.5
      assert item.explanation =~ "Kemiripan semantik CV belum tersedia"
    end

    test "uses semantic only when the job lists no requirements" do
      item =
        Ranker.score_job(
          ["Go"],
          job("job-1", requirements: []),
          semantic: 0.9,
          now: @now
        )

      assert item.skill_score == nil
      assert item.match == 0.9
      assert item.missing_skills == []
      assert item.explanation =~ "tidak mencantumkan skill spesifik"
    end
  end

  describe "rank/3" do
    test "personalizes the best job to each CV rather than listing order" do
      jobs = [
        job("elixir-role", requirements: ["Elixir", "SQL"]),
        job("python-role", requirements: ["Python", "SQL"])
      ]

      [elixir_best | _] = Ranker.rank(%{skills: ["Elixir", "SQL"]}, jobs, now: @now)
      [python_best | _] = Ranker.rank(%{skills: ["Python", "SQL"]}, jobs, now: @now)
      assert elixir_best.job_id == "elixir-role"
      assert python_best.job_id == "python-role"
      assert elixir_best.missing_skills == []
      assert python_best.missing_skills == []
    end

    test "sorts by match score then recency and applies the limit" do
      jobs = [
        job("weak", requirements: ["Go", "Rust"]),
        job("strong", requirements: ["Go"])
      ]

      ranked = Ranker.rank(%{skills: ["Go"]}, jobs, now: @now)

      assert Enum.map(ranked, & &1.job_id) == ["strong", "weak"]
      assert Ranker.rank(%{skills: ["Go"]}, jobs, now: @now, limit: 1) |> length() == 1
    end

    test "scores semantic similarity from the vector map" do
      jobs = [job("same", requirements: []), job("orthogonal", requirements: [])]

      ranked =
        Ranker.rank(%{skills: []}, jobs,
          now: @now,
          query_vector: [1.0, 0.0],
          vectors: %{"same" => [1.0, 0.0], "orthogonal" => [0.0, 1.0]}
        )

      assert hd(ranked).job_id == "same"
      assert hd(ranked).semantic_score == 1.0
      assert List.last(ranked).semantic_score == 0.0
    end
  end

  describe "course recommendations" do
    setup do
      course = %{
        id: "course-1",
        title: "Kubernetes for Backend Engineers",
        description: "Deploy and scale containerized services",
        industries: ["Technology"],
        classes: [%{id: "class-1"}]
      }

      unrelated = %{
        id: "course-2",
        title: "Graphic Design Fundamentals",
        description: "Brand identity and typography",
        industries: ["Design"],
        classes: [%{id: "class-2"}]
      }

      %{course: course, unrelated: unrelated}
    end

    test "only courses covering a missing skill are returned", %{
      course: course,
      unrelated: unrelated
    } do
      assert [recommendation] =
               Ranker.recommend_courses(["Kubernetes"], [course, unrelated])

      assert recommendation.course_id == "course-1"
      assert recommendation.class_id == "class-1"
      assert recommendation.matched_skills == ["Kubernetes"]
      assert recommendation.coverage == 1.0
      assert recommendation.score == 0.7
    end

    test "adds the semantic component when a course vector exists", %{course: course} do
      [recommendation] =
        Ranker.recommend_courses(["Kubernetes"], [course],
          query_vector: [1.0, 0.0],
          vectors: %{"course-1" => [1.0, 0.0]}
        )

      assert recommendation.semantic_score == 1.0
      assert recommendation.score == 1.0
    end

    test "returns nothing when there are no missing skills", %{course: course} do
      assert Ranker.recommend_courses([], [course]) == []
    end

    test "never invents a course when nothing matches", %{course: course} do
      ranked = [%{job_id: "job-1", missing_skills: ["Rust"], match_score: 0.5}]

      assert {[item], []} =
               Ranker.attach_courses(ranked, Ranker.recommend_courses(["Rust"], [course]))

      assert item.course == nil
    end

    test "attaches the best course and aggregates the course list", %{
      course: course,
      unrelated: unrelated
    } do
      recommendations = Ranker.recommend_courses(["Kubernetes"], [course, unrelated])

      ranked = [
        %{
          job_id: "job-1",
          missing_skills: ["Kubernetes"],
          match_score: 0.8
        }
      ]

      assert {[item], [aggregate]} = Ranker.attach_courses(ranked, recommendations)

      assert item.course.course_id == "course-1"
      assert item.course.class_id == "class-1"
      assert aggregate.course_id == "course-1"
      assert aggregate.class_id == "class-1"
      assert aggregate.jobs_covered == 1
      assert aggregate.total_score == 0.7
    end

    test "jobs without missing skills get course: nil", %{course: course} do
      ranked = [%{job_id: "job-1", missing_skills: [], match_score: 1.0}]
      recommendations = Ranker.recommend_courses(["Kubernetes"], [course])

      assert {[item], []} = Ranker.attach_courses(ranked, recommendations)
      assert item.course == nil
    end
  end
end
