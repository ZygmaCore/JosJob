defmodule JosjobWeb.Api.RagController do
  @moduledoc """
  CV → ranking API.

  The heavy PDF/LLM extraction stays in the standalone `josjob_ragpdf` service.
  This controller proxies uploads/status and turns the structured result into a
  deterministic ranking with course recommendations.

  Routes (Bearer auth):

      POST /api/rag/cv/extractions        multipart PDF -> extraction job
      GET  /api/rag/cv/extractions/:id    extraction status/result
      POST /api/rag/analyses              rank a structured CV or an extraction
      GET  /api/rag/analyses/:cv_id       latest persisted analysis
      POST /api/rag/reindex               superuser: re-embed jobs + courses
  """

  use JosjobWeb, :controller

  require Logger

  alias JosjobRag.{Analyses, Analyzer, CandidateProfile, PdfClient}

  @max_limit 50

  def analyze(conn, params) do
    user = conn.assigns.current_user

    with :ok <- validate_review(params),
         {:ok, cv} <- load_cv(params, user),
         {:ok, result} <- Analyzer.analyze(user, cv, limit: limit(params)) do
      data = analysis_json(result) |> persist(user, cv, result)
      json(conn, %{data: data})
    else
      {:error, :not_found} ->
        not_found(conn)

      {:error, :missing_cv_id} ->
        bad_request(conn, %{"cv_id" => "cv_id is required"})

      {:error, {:invalid_params, fields}} ->
        bad_request(conn, fields)

      {:error, {:extraction_pending, status}} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "extraction_pending", status: status})

      {:error, {:extraction_failed, reason}} ->
        unprocessable(conn, "extraction_failed", reason)

      {:error, {:ragpdf, status, body}} when status in 400..499 ->
        forward_pdf_error(conn, status, body)

      {:error, reason} ->
        Logger.warning("RAG analysis failed: #{inspect(reason)}")
        service_unavailable(conn, "rag_unavailable")
    end
  end

  def show(conn, %{"cv_id" => cv_id}) do
    case Analyses.get(conn.assigns.current_user, cv_id) do
      {:ok, analysis} ->
        json(conn, %{data: analysis})

      {:error, :not_found} ->
        not_found(conn)

      {:error, :not_migrated} ->
        service_unavailable(conn, "not_migrated")

      {:error, reason} ->
        Logger.warning("Could not read RAG analysis: #{inspect(reason)}")
        service_unavailable(conn, "rag_unavailable")
    end
  end

  def create_extraction(conn, params) do
    user = conn.assigns.current_user

    if params["consent"] in [true, "true"] do
      submit_extraction(conn, params, user)
    else
      bad_request(conn, %{"consent" => "Explicit consent is required before processing your CV"})
    end
  end

  defp submit_extraction(conn, params, user) do
    case params["file"] do
      %Plug.Upload{} = upload ->
        with {:ok, cv_id} <- PdfClient.version(upload) do
          case CandidateProfile.cv(user, cv_id) do
            {:ok, cv} ->
              conn |> put_status(:accepted) |> json(cached_extraction(cv, user))

            {:error, :not_found} ->
              forward_upload(conn, params, user, upload, cv_id)

            {:error, _reason} ->
              service_unavailable(conn, "cv_storage_unavailable")
          end
        else
          {:error, :pdf_too_large} ->
            conn |> put_status(:request_entity_too_large) |> json(%{error: "payload_too_large"})

          {:error, _reason} ->
            bad_request(conn, %{"file" => "The PDF could not be read"})
        end

      _other ->
        bad_request(conn, %{"file" => "multipart field `file` is required"})
    end
  end

  defp forward_upload(conn, params, user, upload, cv_id) do
    known_skills =
      (Enum.flat_map(Analyzer.load_jobs(user, []), &(&1.requirements || [])) ++
         Josjob.Orgs.SkillData.all())
      |> Enum.uniq()
      |> Enum.take(200)

    opts = [idempotency_key: params["idempotency_key"] || cv_id, known_skills: known_skills]

    case PdfClient.submit_upload(upload, user.id, cv_id, opts) do
      {:ok, body} -> conn |> put_status(:accepted) |> json(body)
      {:error, {:ragpdf, status, body}} -> forward_pdf_error(conn, status, body)
      {:error, _reason} -> service_unavailable(conn, "extraction_service_unavailable")
    end
  end

  defp cached_extraction(cv, user) do
    origin = cv["extraction"] || %{}

    %{
      "data" => %{
        "id" => cv["cv_id"],
        "cv_id" => cv["cv_id"],
        "user_id" => user.id,
        "status" => origin["status"] || "done",
        "cached" => true,
        "provider" => origin["provider"],
        "model" => origin["model"],
        "warnings" => origin["warnings"] || [],
        "result" => Map.take(cv, ["skills", "experience", "education"])
      }
    }
  end

  def show_extraction(conn, %{"id" => id}) do
    case owned_extraction(id, conn.assigns.current_user) do
      {:ok, body} ->
        json(conn, body)

      {:error, :not_found} ->
        not_found(conn)

      {:error, {:ragpdf, 404, _body}} ->
        not_found(conn)

      {:error, {:ragpdf, status, body}} ->
        forward_pdf_error(conn, status, body)

      {:error, reason} ->
        Logger.warning("CV extraction status failed: #{inspect(reason)}")
        service_unavailable(conn, "extraction_service_unavailable")
    end
  end

  def reindex(conn, params) do
    force = params["force"] in [true, "true", "1", 1]

    case Analyzer.reindex_all(force: force) do
      {:ok, summary} ->
        json(conn, %{data: summary})

      {:error, reason} ->
        Logger.warning("RAG reindex failed: #{inspect(reason)}")
        service_unavailable(conn, "reindex_failed")
    end
  end

  # The extraction service uses a shared backend token. Check ownership before
  # exposing private CV data or accepting an extraction for ranking.
  defp owned_extraction(id, user) do
    result =
      if String.starts_with?(id, "cv_pdf_") do
        with {:ok, cv} <- CandidateProfile.cv(user, id), do: {:ok, cached_extraction(cv, user)}
      else
        PdfClient.get(id)
      end

    case result do
      {:ok, %{"data" => %{"user_id" => owner}} = body} when owner == user.id ->
        {:ok, body}

      {:ok, _body} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  # --- CV input -----------------------------------------------------------

  defp load_cv(params, user) do
    cond do
      is_binary(params["extraction_id"]) and params["extraction_id"] != "" ->
        cv_from_extraction(params, user)

      is_binary(params["cv_id"]) and not Map.has_key?(params, "cv") and
          not Enum.any?(["skills", "experience", "education"], &Map.has_key?(params, &1)) ->
        CandidateProfile.cv(user, params["cv_id"])

      is_map(params["cv"]) ->
        cv_from_map(params["cv"], params)

      true ->
        cv_from_map(params, params)
    end
  end

  defp cv_from_extraction(params, user) do
    id = params["extraction_id"]

    case owned_extraction(id, user) do
      {:ok, %{"data" => %{"status" => status, "result" => result} = data}}
      when status in ["done", "partial"] ->
        result = result || %{}

        cv = %{
          "cv_id" => params["cv_id"] || data["cv_id"] || id,
          "skills" => reviewed_skills(params, result),
          "experience" => list(result["experience"]),
          "education" => list(result["education"]),
          "extraction" => Map.take(data, ["status", "provider", "model", "warnings"])
        }

        validate_cv(cv)

      {:ok, %{"data" => %{"status" => status} = data}}
      when status in ["failed", "unreadable", "cancelled"] ->
        {:error, {:extraction_failed, data["error"] || status}}

      {:ok, %{"data" => %{"status" => status}}} ->
        {:error, {:extraction_pending, status}}

      {:ok, %{"data" => data}} ->
        {:error, {:extraction_failed, data["error"] || "extraction_failed"}}

      {:ok, body} ->
        {:error, {:extraction_failed, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cv_from_map(cv, params) do
    cv = %{
      "cv_id" => params["cv_id"] || cv["cv_id"] || cv["id"],
      "skills" => list(cv["skills"]),
      "experience" => list(cv["experience"]),
      "education" => list(cv["education"])
    }

    validate_cv(cv)
  end

  defp validate_cv(%{"cv_id" => cv_id} = cv) do
    cond do
      cv_id in [nil, ""] ->
        {:error, :missing_cv_id}

      cv["skills"] == [] and cv["experience"] == [] and cv["education"] == [] ->
        {:error,
         {:invalid_params,
          %{"cv" => "at least one of skills, experience, or education is required"}}}

      true ->
        {:ok, cv}
    end
  end

  defp list(value) when is_list(value), do: value
  defp list(_value), do: []

  defp validate_review(%{"reviewed_skills" => skills}) do
    if is_list(skills) and length(skills) <= 100 and
         Enum.all?(skills, &(is_binary(&1) and String.length(&1) <= 100)),
       do: :ok,
       else:
         {:error,
          {:invalid_params,
           %{"skills" => "Use up to 100 skill names, each at most 100 characters"}}}
  end

  defp validate_review(_), do: :ok

  defp reviewed_skills(params, result) do
    if Map.has_key?(params, "reviewed_skills"),
      do: JosjobRag.Text.requirement_list(params["reviewed_skills"]),
      else: list(result["skills"])
  end

  defp limit(params) do
    case params["limit"] do
      value when is_integer(value) ->
        value |> max(1) |> min(@max_limit)

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, ""} -> parsed |> max(1) |> min(@max_limit)
          _ -> 10
        end

      _other ->
        10
    end
  end

  # --- responses ----------------------------------------------------------

  defp analysis_json(result) do
    %{
      cv_id: result.cv_id,
      provider: result.provider,
      model: result.model,
      dimensions: result.dimensions,
      semantic: result.semantic,
      analyzed_at: result.analyzed_at,
      scoring: result.scoring,
      method: result.method,
      profile: result.profile,
      jobs: Enum.map(result.jobs, &job_json/1),
      courses: Enum.map(result.courses, &course_json/1)
    }
  end

  defp persist(data, user, cv, result) do
    case CandidateProfile.save(user, cv, result) do
      {:ok, analysis_id} ->
        data
        |> Map.put(:analysis_id, analysis_id)
        |> Map.put(:persisted, true)

      {:error, reason} ->
        Logger.warning("Could not persist RAG analysis: #{inspect(reason)}")

        data
        |> Map.put(:persisted, false)
        |> Map.put(:persist_error, persist_error(reason))
    end
  end

  defp persist_error(:not_migrated), do: "not_migrated"
  defp persist_error(_reason), do: "unavailable"

  defp job_json(item) do
    job = item.job

    %{
      job_id: item.job_id,
      relevance_label: item.relevance_label,
      categories: item.categories,
      match_score: item.match_score,
      match: item.match,
      semantic_score: item.semantic_score,
      skill_score: item.skill_score,
      recency_score: item.recency_score,
      matched_skills: item.matched_skills,
      missing_skills: item.missing_skills,
      explanation: item.explanation,
      course: item.course,
      job: %{
        id: Map.get(job, :id),
        title: Map.get(job, :title),
        description: Map.get(job, :description),
        company: company_name(job),
        organization_id: Map.get(job, :organization_id),
        location: Map.get(job, :location),
        industry: Map.get(job, :industry),
        employment_type: Map.get(job, :employment_type),
        work_mode: Map.get(job, :work_mode),
        requirements: Map.get(job, :requirements) || [],
        highlights: Map.get(job, :highlights) || [],
        salary_min: Map.get(job, :salary_min),
        salary_max: Map.get(job, :salary_max),
        currency: Map.get(job, :currency),
        status: Map.get(job, :status),
        synthetic: Map.get(job, :synthetic) || false,
        posted_at: Map.get(job, :posted_at),
        created_at: Map.get(job, :created_at)
      }
    }
  end

  defp course_json(course) do
    %{
      course_id: course.course_id,
      class_id: course.class_id,
      title: course.title,
      matched_skills: course.matched_skills,
      coverage: course.coverage,
      score: course.score,
      jobs_covered: course[:jobs_covered],
      total_score: course[:total_score]
    }
  end

  defp company_name(job) do
    case Map.get(job, :organization) do
      %{name: name} -> name
      _ -> nil
    end
  end

  # --- errors -------------------------------------------------------------

  defp bad_request(conn, fields) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_params", fields: fields})
  end

  defp unprocessable(conn, error, reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: error, message: inspect(reason, printable_limit: 300)})
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp service_unavailable(conn, error) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: error})
  end

  defp forward_pdf_error(conn, status, body) when status in 400..499 do
    payload =
      case body do
        %{"error" => error} = body ->
          %{error: error, message: body["message"], fields: body["fields"]}

        _ ->
          %{error: "extraction_failed"}
      end

    conn |> put_status(status) |> json(payload)
  end

  defp forward_pdf_error(conn, _status, _body) do
    service_unavailable(conn, "extraction_service_unavailable")
  end
end
