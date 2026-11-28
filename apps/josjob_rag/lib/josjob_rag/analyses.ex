defmodule JosjobRag.Analyses do
  @moduledoc """
  Persistence for CV analyses and their ranked job matches.

  Raw SQL on purpose (same choice as `JosjobRag.VectorStore`): no Ash resource is
  needed just to store an immutable analysis snapshot, and the schema is easy to
  inspect. The tables are created by the `create_rag_pipeline` migration.

  A re-analysis of the same `(user_id, cv_id)` replaces the previous snapshot:
  the analysis row is upserted and its matches are deleted and re-inserted. This
  matches the product flow "belajar → analisis ulang → lihat ranking baru".
  """

  require Logger

  @timeout 15_000

  @doc """
  Persist an analysis returned by `JosjobRag.Analyzer.analyze/3`.

  Returns `{:ok, analysis_id}` or `{:error, reason}`.
  """
  @spec save(map(), map(), map()) :: {:ok, String.t()} | {:error, term()}
  def save(user, cv, result) do
    cv_id = result[:cv_id] || result["cv_id"] || result[:id]

    if is_nil(cv_id) or to_string(cv_id) == "" do
      {:error, :missing_cv_id}
    else
      cv_id = to_string(cv_id)
      jobs = result[:jobs] || result["jobs"] || []
      skills = cv |> fetch(:skills) |> JosjobRag.Text.requirement_list()

      transaction(fn ->
        analysis_id = upsert_analysis(user, cv, result, cv_id, skills)
        _ = query!("delete from rag_job_matches where analysis_id = $1", [analysis_id])
        insert_matches(analysis_id, jobs)
        uuid_string(analysis_id)
      end)
    end
  end

  @doc """
  Load the latest persisted analysis for a user and CV id.

  Returns `{:ok, analysis}` or `{:error, :not_found | term()}`.
  """
  @spec get(map(), String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def get(user, cv_id) when is_binary(cv_id) do
    with {:ok, [analysis]} <-
           query(
             """
             select id, cv_id, provider, model, semantic, analyzed_at, updated_at, payload
             from rag_cv_analyses
             where user_id = $1 and cv_id = $2
             limit 1
             """,
             [dump_uuid!(user.id), cv_id]
           ) do
      {:ok, rows} = query(matches_sql(), [analysis["id"]])

      jobs = Enum.map(rows, &match_json/1)
      courses = aggregate_courses(jobs)

      {:ok,
       %{
         cv_id: analysis["cv_id"],
         profile: analysis["payload"]["matching_profile"],
         method: analysis["payload"]["matching_profile"] && "category_skill",
         provider: analysis["provider"],
         model: analysis["model"],
         semantic: analysis["semantic"],
         analyzed_at: iso8601(analysis["analyzed_at"]),
         jobs: jobs,
         courses: courses,
         persisted: true
       }}
    else
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def get(_user, _cv_id), do: {:error, :not_found}

  @doc "Load reusable extracted CV facts, scoped to the owner; nil selects the latest saved CV."
  def cv(user, cv_id \\ nil)
  def cv(nil, _cv_id), do: {:error, :unauthorized}

  def cv(user, cv_id) do
    with {:ok, rows} <-
           query(
             """
             select cv_id, payload from rag_cv_analyses
             where user_id = $1 and ($2::text is null or cv_id = $2)
             order by updated_at desc, id desc limit 1
             """,
             [dump_uuid!(user.id), cv_id]
           ) do
      case rows do
        [row] -> {:ok, Map.put(row["payload"], "cv_id", row["cv_id"])}
        [] -> {:error, :not_found}
      end
    end
  end

  @doc "Delete a persisted analysis (matches cascade)."
  def delete(user, cv_id) when is_binary(cv_id) do
    case query("delete from rag_cv_analyses where user_id = $1 and cv_id = $2 returning id", [
           dump_uuid!(user.id),
           cv_id
         ]) do
      {:ok, rows} -> {:ok, length(rows)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Load the most recent analyses for a user."
  def list(user, limit \\ 20) do
    query(
      """
      select cv_id, provider, model, semantic, analyzed_at, updated_at
      from rag_cv_analyses
      where user_id = $1
      order by analyzed_at desc nulls last
      limit $2
      """,
      [dump_uuid!(user.id), min(max(limit, 1), 100)]
    )
    |> case do
      {:ok, rows} ->
        {:ok,
         Enum.map(rows, fn row ->
           %{
             cv_id: row["cv_id"],
             provider: row["provider"],
             model: row["model"],
             semantic: row["semantic"],
             analyzed_at: iso8601(row["analyzed_at"])
           }
         end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- writes -------------------------------------------------------------

  defp upsert_analysis(user, cv, result, cv_id, skills) do
    payload =
      cv |> json_safe() |> Map.put("matching_profile", JosjobRag.CategoryRanking.profile(cv))

    [row] =
      query!(
        """
        insert into rag_cv_analyses
          (user_id, cv_id, provider, model, cv_text, skills, payload, semantic, analyzed_at, inserted_at, updated_at)
        values
          ($1, $2, $3, $4, $5, $6, $7, $8, $9, now(), now())
        on conflict (user_id, cv_id) do update set
          provider = excluded.provider,
          model = excluded.model,
          cv_text = excluded.cv_text,
          skills = excluded.skills,
          payload = excluded.payload,
          semantic = excluded.semantic,
          analyzed_at = excluded.analyzed_at,
          updated_at = now()
        returning id
        """,
        [
          dump_uuid!(user.id),
          cv_id,
          result[:provider],
          result[:model],
          JosjobRag.Text.cv_text(cv),
          skills,
          payload,
          result[:semantic] == true,
          result[:analyzed_at]
        ]
      )

    row["id"]
  end

  defp insert_matches(analysis_id, jobs) do
    jobs
    |> Enum.with_index(1)
    |> Enum.each(fn {item, position} ->
      job_id = item[:job_id] || item.job[:id]

      case Ecto.UUID.dump(job_id) do
        {:ok, job_id} ->
          course = item[:course]

          query!(
            """
            insert into rag_job_matches
              (analysis_id, job_id, rank_position, match_score, match, semantic_score,
               skill_score, recency_score, matched_skills, missing_skills, explanation,
               course_id, class_id, inserted_at)
            values
              ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, now())
            """,
            [
              analysis_id,
              job_id,
              position,
              item.match_score,
              item.match,
              item.semantic_score,
              item.skill_score,
              item.recency_score,
              item.matched_skills,
              item.missing_skills,
              item.explanation,
              cast_uuid(course && (course[:course_id] || course["course_id"])),
              cast_uuid(course && (course[:class_id] || course["class_id"]))
            ]
          )

        :error ->
          Logger.warning("Skipping persistence for non-UUID job id #{inspect(job_id)}")
      end
    end)
  end

  # --- reads --------------------------------------------------------------

  defp matches_sql do
    """
    select m.job_id, m.rank_position, m.match_score, m.match, m.semantic_score,
           m.skill_score, m.recency_score, m.matched_skills, m.missing_skills,
           m.explanation, m.course_id, m.class_id,
           j.title, j.location, j.industry, j.employment_type, j.work_mode,
           j.status, j.posted_at,
           o.name as company_name,
           c.title as course_title
    from rag_job_matches m
    join jobs j on j.id = m.job_id
    left join organizations o on o.id = j.organization_id
    left join courses c on c.id = m.course_id
    where m.analysis_id = $1
    order by m.rank_position asc
    """
  end

  defp match_json(row) do
    %{
      job_id: uuid_string(row["job_id"]),
      rank: row["rank_position"],
      match_score: row["match_score"],
      match: row["match"],
      semantic_score: row["semantic_score"],
      skill_score: row["skill_score"],
      recency_score: row["recency_score"],
      matched_skills: row["matched_skills"] || [],
      missing_skills: row["missing_skills"] || [],
      explanation: row["explanation"],
      job: %{
        id: uuid_string(row["job_id"]),
        title: row["title"],
        company: row["company_name"],
        location: row["location"],
        industry: row["industry"],
        employment_type: row["employment_type"],
        work_mode: row["work_mode"],
        status: row["status"],
        posted_at: iso8601(row["posted_at"])
      },
      course:
        if(row["course_id"]) do
          %{
            course_id: uuid_string(row["course_id"]),
            class_id: uuid_string(row["class_id"]),
            title: row["course_title"]
          }
        else
          nil
        end
    }
  end

  defp aggregate_courses(jobs) do
    jobs
    |> Enum.map(& &1.course)
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(& &1.course_id)
    |> Enum.map(fn {_id, courses} ->
      first = hd(courses)
      Map.put(first, :jobs_covered, length(courses))
    end)
    |> Enum.sort_by(&{-&1.jobs_covered, &1.title || ""})
  end

  # --- SQL helpers --------------------------------------------------------

  defp transaction(fun) do
    case Josjob.Repo.transaction(fun) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  rescue
    exception -> {:error, normalize_error(exception)}
  catch
    :exit, reason -> {:error, normalize_error(reason)}
  end

  defp query(sql, params) do
    case Ecto.Adapters.SQL.query(Josjob.Repo, sql, params, timeout: @timeout) do
      {:ok, %{columns: columns, rows: rows}} ->
        # Statements without `RETURNING` report `rows: nil`.
        {:ok, Enum.map(rows || [], fn row -> Map.new(Enum.zip(columns || [], row)) end)}

      {:error, reason} ->
        {:error, normalize_error(reason)}
    end
  rescue
    exception -> {:error, normalize_error(exception)}
  catch
    :exit, reason -> {:error, normalize_error(reason)}
  end

  defp query!(sql, params) do
    case query(sql, params) do
      {:ok, rows} -> rows
      {:error, reason} -> Josjob.Repo.rollback(reason)
    end
  end

  defp normalize_error(%Postgrex.Error{postgres: %{code: :undefined_table}}), do: :not_migrated
  defp normalize_error(%Postgrex.Error{postgres: %{code: :undefined_column}}), do: :not_migrated
  defp normalize_error(%Postgrex.Error{message: message}), do: {:postgres, message}

  defp normalize_error(%{__exception__: true} = error),
    do: {:store_unavailable, Exception.message(error)}

  defp normalize_error(reason), do: reason

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {to_string(key), json_safe(item)} end)
  end

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)

  defp json_safe(value) when is_atom(value) and value not in [nil, true, false],
    do: to_string(value)

  defp json_safe(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_safe()
  defp json_safe(value), do: value

  defp cast_uuid(nil), do: nil

  defp cast_uuid(value) do
    case Ecto.UUID.dump(value) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  # Raw Postgrex queries expect the 16-byte form for `uuid` parameters.
  defp dump_uuid!(<<_::128>> = raw), do: raw
  defp dump_uuid!(value), do: Ecto.UUID.dump!(value)

  # Raw Postgrex queries return `uuid` as a 16-byte binary; JSON needs the
  # canonical string form.
  defp uuid_string(nil), do: nil

  defp uuid_string(<<_::128>> = raw), do: Ecto.UUID.load!(raw)
  defp uuid_string(value) when is_binary(value), do: value
  defp uuid_string(_value), do: nil

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso8601(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value) <> "Z"
  defp iso8601(value) when is_binary(value), do: value
  defp iso8601(value), do: to_string(value)

  defp fetch(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp fetch(_other, _key), do: nil
end
