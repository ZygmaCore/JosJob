defmodule JosjobRag.Ranker do
  @moduledoc """
  Deterministic, explainable ranking v1 for CV ↔ job matching, plus the course
  recommendation hook.

  ## Formula

      match  = 0.6 * semantic + 0.4 * skill_overlap
      score  = 0.85 * match    + 0.15 * recency

    * `semantic` — cosine similarity between the CV embedding and the job
      embedding, clamped to `0.0..1.0`. When either vector is missing the
      semantic component is `nil` and `match` uses skill overlap alone.
    * `skill_overlap` — matched requirements / all requirements. A job with no
      requirements has no skill score, so `match` uses the semantic component.
    * `recency` — exponential decay with a 30-day half-life:
      `0.5 ^ (age_days / 30)`. Jobs with no `posted_at` get the neutral value
      `0.5`.

  All constants are named module attributes and exposed through `weights/0` so
  the same inputs always reproduce the same ranking and the UI can explain it.

  ## Course hook

  Courses are recommended **only for missing skills**. A course's score is
  `0.7 * coverage + 0.3 * semantic`, where coverage is the fraction of the
  candidate's missing skills the course covers. Courses that cover none of the
  gaps are dropped, and `course: null` is returned when no real course matches —
  the ranker never invents a course or class id.
  """

  alias JosjobRag.{Cosine, Text}

  @semantic_weight 0.6
  @skill_weight 0.4
  @match_weight 0.85
  @recency_weight 0.15
  @recency_half_life_days 30.0
  @unknown_recency 0.5
  @course_skill_weight 0.7
  @course_semantic_weight 0.3
  @max_listed 5

  @type ranked_job :: map()

  @doc "Named weights used by the ranker; surfaced in docs and tests."
  def weights do
    %{
      semantic: @semantic_weight,
      skill: @skill_weight,
      match: @match_weight,
      recency: @recency_weight,
      recency_half_life_days: @recency_half_life_days,
      unknown_recency: @unknown_recency,
      course_skill: @course_skill_weight,
      course_semantic: @course_semantic_weight
    }
  end

  @doc """
  Rank jobs for a CV.

  Options:

    * `:query_vector` — embedded CV vector (optional)
    * `:vectors` — map of job id to embedded vector (optional)
    * `:now` — reference time, defaults to `DateTime.utc_now/0`
    * `:limit` — maximum number of ranked jobs
  """
  @spec rank(map(), [map()], keyword()) :: [ranked_job()]
  def rank(cv, jobs, opts \\ []) when is_list(jobs) do
    query_vector = opts[:query_vector]
    vectors = opts[:vectors] || %{}
    now = opts[:now] || DateTime.utc_now()
    cv_skills = cv_skills(cv)

    jobs
    |> Enum.map(fn job ->
      semantic =
        case Map.get(vectors, to_string(job_id(job))) do
          nil -> nil
          vector -> semantic_score(query_vector, vector)
        end

      score_job(cv_skills, job, semantic: semantic, now: now)
    end)
    |> Enum.sort_by(fn item ->
      {-item.match_score, -item.recency_score, to_string(item.job_id)}
    end)
    |> maybe_limit(opts[:limit])
  end

  @doc """
  Score one job against a CV.

  `cv_skills` is the already-normalized skill list; `opts[:semantic]` is the
  cosine score or `nil`; `opts[:now]` is the reference time.
  """
  @spec score_job([String.t()], map(), keyword()) :: ranked_job()
  def score_job(cv_skills, job, opts \\ []) do
    requirements = Text.requirement_list(get(job, :requirements))
    {matched, missing} = Text.split_skills(requirements, cv_skills)
    semantic = opts[:semantic]
    now = opts[:now] || DateTime.utc_now()
    posted_at = get(job, :posted_at)

    skill = skill_score(matched, requirements)
    recency = recency_score(posted_at, now)
    match = match_score(semantic, skill)
    score = @match_weight * match + @recency_weight * recency
    age_days = age_days(posted_at, now)

    %{
      job_id: job_id(job),
      job: job,
      match_score: round_score(score),
      match: round_score(match),
      semantic_score: round_or_nil(semantic),
      skill_score: round_or_nil(skill),
      recency_score: round_score(recency),
      matched_skills: matched,
      missing_skills: missing,
      requirements: requirements,
      age_days: age_days,
      explanation: explanation(matched, missing, requirements, semantic, age_days)
    }
  end

  @doc """
  Score courses against a list of missing skills.

  Only courses that cover at least one missing skill are returned. The result is
  sorted by score descending, then title. `opts` accepts `:query_vector` (CV
  vector) and `:vectors` (course id -> vector).
  """
  @spec recommend_courses([String.t()], [map()], keyword()) :: [map()]
  def recommend_courses(missing_skills, courses, opts \\ []) when is_list(courses) do
    missing = Text.requirement_list(missing_skills)
    query_vector = opts[:query_vector]
    vectors = opts[:vectors] || %{}

    if missing == [] do
      []
    else
      courses
      |> Enum.map(&score_course(&1, missing, query_vector, vectors))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn course -> {-course.score, -course.coverage, course.title || ""} end)
    end
  end

  @doc """
  Attach the best course to every ranked job and aggregate the course list.

  Returns `{ranked_jobs, recommended_courses}`. A job without missing skills, or
  without a course that covers a missing skill, gets `course: nil`.
  """
  @spec attach_courses([ranked_job()], [map()]) :: {[ranked_job()], [map()]}
  def attach_courses(ranked_jobs, course_recommendations) do
    {ranked_jobs, used} =
      Enum.map_reduce(ranked_jobs, [], fn item, used ->
        case best_course(item.missing_skills, course_recommendations) do
          nil ->
            {Map.put(item, :course, nil), used}

          course ->
            {Map.put(item, :course, course_link(course)), [course | used]}
        end
      end)

    courses =
      used
      |> Enum.group_by(& &1.course_id)
      |> Enum.map(fn {_id, recs} ->
        first = hd(recs)

        first
        |> course_link()
        |> Map.merge(%{
          jobs_covered: length(recs),
          total_score: round_score(Enum.sum(Enum.map(recs, & &1.score)))
        })
      end)
      |> Enum.sort_by(fn course ->
        {-course.jobs_covered, -course.total_score, course.title || ""}
      end)

    {ranked_jobs, courses}
  end

  @doc "Recency factor for a `posted_at` value and a reference time."
  @spec recency_score(term(), DateTime.t()) :: float()
  def recency_score(nil, _now), do: @unknown_recency

  def recency_score(%DateTime{} = posted_at, %DateTime{} = now) do
    days = max(DateTime.diff(now, posted_at, :second) / 86_400.0, 0.0)
    :math.pow(0.5, days / @recency_half_life_days)
  end

  def recency_score(%NaiveDateTime{} = posted_at, %DateTime{} = now) do
    recency_score(DateTime.from_naive!(posted_at, "Etc/UTC"), now)
  end

  def recency_score(_posted_at, _now), do: @unknown_recency

  @doc "Combined match component; `nil` parts are omitted and the rest reweighted."
  @spec match_score(float() | nil, float() | nil) :: float()
  def match_score(nil, nil), do: 0.0
  def match_score(semantic, nil), do: clamp(semantic)
  def match_score(nil, skill), do: clamp(skill)
  def match_score(semantic, skill), do: clamp(@semantic_weight * semantic + @skill_weight * skill)

  defp score_course(course, missing, query_vector, vectors) do
    title = get(course, :title)
    course_id = get(course, :id)
    course_text = Text.course_text(course)
    course_tokens = MapSet.new(Text.tokens(course_text))
    declared_skills = Text.requirement_list(get(course, :skills) || get(course, :requirements))

    matched =
      Enum.filter(missing, fn skill ->
        covers_skill?(skill, declared_skills, course_tokens)
      end)

    if course_id && matched != [] do
      coverage = length(matched) / length(missing)

      semantic =
        case Map.get(vectors, to_string(course_id)) do
          nil -> 0.0
          vector -> semantic_score(query_vector, vector) || 0.0
        end

      score = @course_skill_weight * coverage + @course_semantic_weight * semantic

      %{
        course_id: to_string(course_id),
        class_id: course_class_id(course),
        title: title,
        description: get(course, :description),
        matched_skills: matched,
        coverage: round_score(coverage),
        semantic_score: round_score(semantic),
        score: round_score(score),
        course: course
      }
    end
  end

  defp covers_skill?(skill, declared_skills, course_tokens) do
    declared? = Enum.any?(declared_skills, &Text.same_skill?(&1, skill))
    skill_tokens = Text.tokens(skill)

    declared? or
      (skill_tokens != [] and MapSet.subset?(MapSet.new(skill_tokens), course_tokens))
  end

  defp best_course(missing_skills, courses) do
    missing = MapSet.new(Text.requirement_list(missing_skills))

    courses
    |> Enum.map(fn course ->
      overlap =
        Enum.count(course.matched_skills, fn skill ->
          Enum.any?(missing, &Text.same_skill?(&1, skill))
        end)

      {overlap, course}
    end)
    |> Enum.filter(fn {overlap, _course} -> overlap > 0 end)
    |> Enum.max_by(
      fn {overlap, course} -> {overlap, course.score} end,
      fn -> nil end
    )
    |> case do
      nil -> nil
      {_overlap, course} -> course
    end
  end

  defp course_link(course) do
    %{
      course_id: course.course_id,
      class_id: course.class_id,
      title: course.title,
      matched_skills: course.matched_skills,
      coverage: course.coverage,
      score: course.score
    }
  end

  defp course_class_id(course) do
    case get(course, :classes) do
      [first | _] -> get(first, :id)
      _ -> nil
    end
  end

  defp explanation(matched, missing, requirements, semantic, age_days) do
    skill_sentence =
      cond do
        requirements == [] ->
          "Lowongan tidak mencantumkan skill spesifik"

        matched == [] ->
          "Belum ada skill yang cocok dari #{length(requirements)} yang diminta"

        true ->
          "#{length(matched)} dari #{length(requirements)} skill terpenuhi (#{join_limited(matched)})"
      end

    semantic_sentence =
      case semantic do
        nil -> "Kemiripan semantik CV belum tersedia"
        value -> "Kemiripan semantik CV #{(value * 100) |> round()}%"
      end

    age_sentence =
      case age_of(age_days) do
        nil -> "Tanggal posting tidak tersedia"
        text -> "Diposting #{text}"
      end

    missing_sentence =
      case missing do
        [] -> "Semua skill yang diminta sudah ada"
        skills -> "Skill yang perlu dipelajari: #{join_limited(skills)}"
      end

    [skill_sentence, semantic_sentence, age_sentence, missing_sentence]
    |> Enum.map(&String.trim_trailing(&1, "."))
    |> Enum.join(". ")
    |> Kernel.<>(".")
  end

  defp age_of(nil), do: nil
  defp age_of(days) when days < 1.0, do: "hari ini"
  defp age_of(days) when days < 30.0, do: "#{round(days)} hari lalu"
  defp age_of(days) when days < 365.0, do: "#{round(days / 30)} bulan lalu"
  defp age_of(days), do: "#{round(days / 365)} tahun lalu"

  defp age_days(%DateTime{} = posted_at, %DateTime{} = now) do
    max(DateTime.diff(now, posted_at, :second) / 86_400.0, 0.0)
  end

  defp age_days(%NaiveDateTime{} = posted_at, %DateTime{} = now) do
    age_days(DateTime.from_naive!(posted_at, "Etc/UTC"), now)
  end

  defp age_days(_posted_at, _now), do: nil

  defp skill_score(_matched, []), do: nil
  defp skill_score(matched, requirements), do: length(matched) / length(requirements)

  defp semantic_score(nil, _vector), do: nil
  defp semantic_score(_query, nil), do: nil
  defp semantic_score(query, vector), do: Cosine.similarity_to_score(query, vector)

  defp join_limited([]), do: ""

  defp join_limited(items) when length(items) <= @max_listed do
    Enum.join(items, ", ")
  end

  defp join_limited(items) do
    Enum.join(Enum.take(items, @max_listed), ", ") <>
      ", +#{length(items) - @max_listed} lainnya"
  end

  defp cv_skills(cv) do
    cv
    |> get(:skills)
    |> Text.requirement_list()
  end

  defp job_id(job), do: get(job, :id)

  defp get(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp get(_other, _key), do: nil

  defp maybe_limit(items, nil), do: items
  defp maybe_limit(items, limit) when is_integer(limit) and limit > 0, do: Enum.take(items, limit)
  defp maybe_limit(items, _limit), do: items

  defp round_or_nil(nil), do: nil
  defp round_or_nil(value), do: round_score(value)

  defp round_score(value) when is_number(value), do: Float.round(value * 1.0, 4)
  defp round_score(_value), do: 0.0

  defp clamp(value), do: value |> max(0.0) |> min(1.0)
end
