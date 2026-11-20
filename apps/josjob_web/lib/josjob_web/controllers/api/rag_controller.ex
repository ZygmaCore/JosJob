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

  alias JosjobRag.{Analyses, Analyzer, PdfClient}

  @max_limit 50

  def analyze(conn, params) do
    user = conn.assigns.current_user

    with {:ok, cv} <- load_cv(params),
         {:ok, result} <- Analyzer.analyze(user, cv, limit: limit(params)) do
      data = analysis_json(result) |> persist(user, cv, result)
      json(conn, %{data: data})
    else
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

    case params["file"] do
      %Plug.Upload{} = upload ->
        opts = [idempotency_key: params["idempotency_key"]]

        case PdfClient.submit_upload(upload, user.id, params["cv_id"], opts) do
          {:ok, body} ->
            conn |> put_status(:accepted) |> json(body)

          {:error, {:ragpdf, status, body}} ->
            forward_pdf_error(conn, status, body)

          {:error, reason} ->
            Logger.warning("CV extraction submit failed: #{inspect(reason)}")
            service_unavailable(conn, "extraction_service_unavailable")
        end

      _other ->
        bad_request(conn, %{"file" => "multipart field `file` is required"})
    end
  end

  def show_extraction(conn, %{"id" => id}) do
    case PdfClient.get(id) do
      {:ok, body} ->
        json(conn, body)

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

  # --- CV input -----------------------------------------------------------

  defp load_cv(params) do
    cond do
      is_binary(params["extraction_id"]) and params["extraction_id"] != "" ->
        cv_from_extraction(params)

      is_map(params["cv"]) ->
        cv_from_map(params["cv"], params)

      true ->
        cv_from_map(params, params)
    end
  end

  defp cv_from_extraction(params) do
    id = params["extraction_id"]

    case PdfClient.get(id) do
      {:ok, %{"data" => %{"status" => status, "result" => result} = data}}
      when status in ["done", "partial"] ->
        result = result || %{}

        cv = %{
          "cv_id" => params["cv_id"] || data["cv_id"] || id,
          "skills" => list(result["skills"]),
          "experience" => list(result["experience"]),
          "education" => list(result["education"])
        }

        validate_cv(cv)

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
      jobs: Enum.map(result.jobs, &job_json/1),
      courses: Enum.map(result.courses, &course_json/1)
    }
  end

  defp persist(data, user, cv, result) do
    case Analyses.save(user, cv, result) do
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
