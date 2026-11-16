defmodule JosjobRagpdfWeb.Controllers.AnalysisController do
  @moduledoc """
  HTTP endpoints for CV analysis jobs.

  Controllers only validate and enqueue. All heavy work happens in
  `JosjobRagpdf.Worker`, so the client can upload and leave.
  """

  import Plug.Conn

  alias JosjobRagpdf.{Id, Job, Jobs, Queue, Temp}
  alias JosjobRagpdfWeb.JSON

  @max_field_length 200
  @max_url_length 2_048
  @max_skills 200

  @doc "POST /v1/cv/analyses"
  def create(conn) do
    params = conn.body_params || %{}

    with {:ok, user_id} <- required_string(params, "user_id"),
         {:ok, cv_id} <- optional_string(params, "cv_id"),
         {:ok, idempotency_key} <- optional_string(params, "idempotency_key"),
         {:ok, known_skills} <- known_skills(params["known_skills"]) do
      scoped_key = scope_idempotency(user_id, idempotency_key)

      case scoped_key && Jobs.find_by_idempotency(scoped_key) do
        {:ok, existing} ->
          JSON.send_data(conn, 200, existing |> Jobs.public() |> Map.put(:queue_position, 0))

        _ ->
          enqueue(conn, params, user_id, cv_id, known_skills, scoped_key)
      end
    else
      {:error, fields} when is_map(fields) ->
        JSON.send_error(conn, 422, "validation_failed", "invalid or missing fields", fields)

      {:error, status, error, message} ->
        JSON.send_error(conn, status, error, message)
    end
  end

  @doc "GET /v1/cv/analyses/:id"
  def show(conn) do
    case Jobs.get(conn.path_params["id"]) do
      {:ok, job} -> JSON.send_data(conn, 200, Jobs.public(job))
      {:error, :not_found} -> JSON.not_found(conn, "analysis not found")
    end
  end

  @doc "DELETE /v1/cv/analyses/:id"
  def delete(conn) do
    case Jobs.get(conn.path_params["id"]) do
      {:ok, job} ->
        delete_job(conn, job)

      {:error, :not_found} ->
        JSON.not_found(conn, "analysis not found")
    end
  end

  defp delete_job(conn, %Job{} = job) do
    if Job.terminal?(job) do
      discard(job)
      send_resp(conn, 204, "")
    else
      case Queue.cancel(job.id) do
        :ok ->
          send_resp(conn, 204, "")

        {:error, :not_found} ->
          discard(job)
          send_resp(conn, 204, "")

        {:error, :processing} ->
          JSON.send_error(conn, 409, "conflict", "analysis is already processing")

        {:error, _} ->
          JSON.send_error(conn, 409, "conflict", "analysis could not be cancelled")
      end
    end
  end

  defp enqueue(conn, params, user_id, cv_id, known_skills, idempotency_key) do
    job_id = Id.generate("job")

    case fetch_source(params, job_id) do
      {:ok, source, filename} ->
        job = %Job{
          id: job_id,
          user_id: user_id,
          cv_id: cv_id,
          filename: filename,
          source: source,
          status: :queued,
          chunks_done: 0,
          warnings: [],
          known_skills: known_skills,
          inserted_at: DateTime.utc_now(),
          idempotency_key: idempotency_key
        }

        create_and_submit(conn, job)

      {:error, status, error, message} ->
        Temp.cleanup(job_id)
        JSON.send_error(conn, status, error, message)
    end
  end

  defp create_and_submit(conn, %Job{} = job) do
    case Jobs.create(job) do
      :ok ->
        case Queue.submit(job) do
          {:ok, position} ->
            data = job |> Jobs.public() |> Map.put(:queue_position, position)
            JSON.send_data(conn, 202, data)

          {:error, :queue_full} ->
            discard(job)
            JSON.send_error(conn, 429, "queue_full", "analysis queue is full, retry later")

          {:error, :duplicate} ->
            discard(job)
            JSON.send_error(conn, 409, "conflict", "analysis is already queued")

          {:error, reason} ->
            discard(job)
            JSON.send_error(conn, 500, "internal_error", "could not enqueue analysis: #{reason}")
        end

      {:error, :exists} ->
        discard(job)
        JSON.send_error(conn, 409, "conflict", "analysis id already exists")
    end
  end

  # --- source resolution -------------------------------------------------

  defp fetch_source(params, job_id) do
    cond do
      match?(%Plug.Upload{}, params["file"]) ->
        from_upload(params["file"], params["filename"], job_id)

      present?(params["file_url"]) ->
        from_url(params["file_url"], params["filename"])

      present?(params["content_base64"]) ->
        from_base64(params["content_base64"], params["filename"], job_id)

      present?(params["file"]) ->
        {:error, 400, "invalid_params", "file must be sent as a multipart upload"}

      true ->
        {:error, 422, "validation_failed", "one of file, file_url, or content_base64 is required"}
    end
  end

  defp from_upload(%Plug.Upload{} = upload, filename_param, job_id) do
    filename = sanitize_filename(filename_param || upload.filename)
    max_bytes = max_pdf_bytes()

    cond do
      not pdf_upload?(upload, filename) ->
        {:error, 415, "unsupported_media_type", "only PDF files are accepted"}

      true ->
        case File.stat(upload.path) do
          {:ok, %File.Stat{size: size}} when size == 0 ->
            {:error, 422, "validation_failed", "uploaded PDF is empty"}

          {:ok, %File.Stat{size: size}} when size > max_bytes ->
            {:error, 413, "payload_too_large", "PDF exceeds the configured maximum size"}

          {:ok, %File.Stat{size: size}} ->
            if pdf_magic?(upload.path) do
              copy_upload(upload, filename, job_id, size)
            else
              {:error, 415, "unsupported_media_type", "file is not a valid PDF"}
            end

          {:error, _} ->
            {:error, 400, "invalid_params", "uploaded file is not readable"}
        end
    end
  end

  defp copy_upload(%Plug.Upload{} = upload, filename, job_id, _size) do
    dir = Temp.ensure_job_dir(job_id)
    dest = Path.join(dir, "source.pdf")

    case File.cp(upload.path, dest) do
      :ok -> {:ok, {:upload, dest}, filename}
      {:error, _} -> {:error, 500, "internal_error", "could not store uploaded PDF"}
    end
  rescue
    _ -> {:error, 500, "internal_error", "could not store uploaded PDF"}
  end

  defp from_url(url, filename_param) when is_binary(url) do
    url = String.trim(url)

    cond do
      String.length(url) > @max_url_length ->
        {:error, 422, "validation_failed", "file_url is too long"}

      true ->
        case URI.parse(url) do
          %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
            filename =
              sanitize_filename(filename_param || Path.basename(URI.parse(url).path || ""))

            {:ok, {:url, url}, filename}

          _ ->
            {:error, 422, "validation_failed", "file_url must be an http(s) URL"}
        end
    end
  end

  defp from_base64(data, filename_param, job_id) when is_binary(data) do
    filename = sanitize_filename(filename_param)

    with {:ok, decoded} <- decode_base64(data),
         :ok <- check_decoded_size(decoded),
         :ok <- check_decoded_magic(decoded) do
      dir = Temp.ensure_job_dir(job_id)
      dest = Path.join(dir, "source.pdf")

      case File.write(dest, decoded) do
        :ok -> {:ok, {:upload, dest}, filename}
        {:error, _} -> {:error, 500, "internal_error", "could not store uploaded PDF"}
      end
    end
  end

  defp decode_base64(data) do
    data =
      case String.split(data, ",", parts: 2) do
        [meta, rest] -> if String.contains?(meta, ";base64"), do: rest, else: data
        _ -> data
      end

    data = String.trim(data)

    case Base.decode64(data) do
      {:ok, decoded} ->
        {:ok, decoded}

      :error ->
        case Base.decode64(data, padding: false) do
          {:ok, decoded} -> {:ok, decoded}
          :error -> {:error, 400, "invalid_params", "content_base64 is not valid base64"}
        end
    end
  end

  defp check_decoded_size(decoded) do
    cond do
      byte_size(decoded) == 0 ->
        {:error, 422, "validation_failed", "decoded PDF is empty"}

      byte_size(decoded) > max_pdf_bytes() ->
        {:error, 413, "payload_too_large", "PDF exceeds the configured maximum size"}

      true ->
        :ok
    end
  end

  defp check_decoded_magic(decoded) do
    if String.starts_with?(decoded, "%PDF-") or
         String.contains?(binary_part(decoded, 0, min(1_024, byte_size(decoded))), "%PDF-") do
      :ok
    else
      {:error, 415, "unsupported_media_type", "content is not a valid PDF"}
    end
  end

  # --- validation helpers ------------------------------------------------

  defp required_string(params, field) do
    case params[field] do
      value when is_binary(value) ->
        value = String.trim(value)

        cond do
          value == "" -> {:error, %{field => "is required"}}
          String.length(value) > @max_field_length -> {:error, %{field => "is too long"}}
          true -> {:ok, value}
        end

      _ ->
        {:error, %{field => "is required"}}
    end
  end

  defp optional_string(params, field) do
    case params[field] do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        value = String.trim(value)

        cond do
          value == "" -> {:ok, nil}
          String.length(value) > @max_field_length -> {:error, %{field => "is too long"}}
          true -> {:ok, value}
        end

      _ ->
        {:error, %{field => "must be a string"}}
    end
  end

  defp known_skills(nil), do: {:ok, []}
  defp known_skills(""), do: {:ok, []}
  defp known_skills(list) when is_list(list), do: normalize_skills(list)

  defp known_skills(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> normalize_skills(list)
      _ -> {:error, %{"known_skills" => "must be a JSON array"}}
    end
  end

  defp known_skills(_), do: {:error, %{"known_skills" => "must be a JSON array"}}

  defp normalize_skills(list) do
    skills =
      list
      |> Enum.map(&skill_name/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&String.downcase/1)
      |> Enum.take(@max_skills)

    {:ok, skills}
  end

  defp skill_name(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      name -> name
    end
  end

  defp skill_name(%{"name" => name}) when is_binary(name), do: skill_name(name)
  defp skill_name(%{name: name}) when is_binary(name), do: skill_name(name)
  defp skill_name(_), do: nil

  defp scope_idempotency(_user_id, nil), do: nil
  defp scope_idempotency(user_id, key), do: user_id <> ":" <> key

  # --- file helpers ------------------------------------------------------

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  defp pdf_upload?(%Plug.Upload{} = upload, filename) do
    pdf_name?(filename) or pdf_mime?(upload.content_type)
  end

  defp pdf_name?(nil), do: false

  defp pdf_name?(filename) when is_binary(filename) do
    filename |> String.downcase() |> String.ends_with?(".pdf")
  end

  defp pdf_mime?(mime) when is_binary(mime),
    do: mime in ["application/pdf", "application/x-pdf", "application/octet-stream"]

  defp pdf_mime?(_), do: false

  defp pdf_magic?(path) do
    case File.open(path, [:read, :binary], fn file -> IO.binread(file, 1_024) end) do
      {:ok, data} when is_binary(data) -> String.contains?(data, "%PDF-")
      _ -> false
    end
  end

  defp sanitize_filename(nil), do: "cv.pdf"

  defp sanitize_filename(filename) when is_binary(filename) do
    filename =
      filename
      |> Path.basename()
      |> String.replace(~r/[\x00-\x1f\x7f]/, "")
      |> String.trim()
      |> String.slice(0, 180)

    case filename do
      "" -> "cv.pdf"
      name -> name
    end
  end

  defp sanitize_filename(_), do: "cv.pdf"

  defp max_pdf_bytes, do: Application.get_env(:josjob_ragpdf, :max_pdf_bytes, 10_000_000)

  defp discard(%Job{} = job) do
    Jobs.delete(job.id)
    Temp.cleanup(job.id)
    :ok
  end
end
