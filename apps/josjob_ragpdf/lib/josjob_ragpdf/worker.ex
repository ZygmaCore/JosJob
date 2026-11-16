defmodule JosjobRagpdf.Worker do
  @moduledoc """
  One CV extraction job.

  The worker is deliberately side-effect free with respect to the queue: it
  updates `JosjobRagpdf.Jobs`, calls the injected PDF/AI/HTTP modules, and always
  removes the job temp directory in an `after` block.

  ## Injectable modules

    * `:pdf` — defaults to `JosjobRagpdf.Pdf`
    * `:ai` — defaults to `JosjobRagpdf.AI`
    * `:http` — defaults to `JosjobRagpdf.HTTP`
    * `:tmp_dir` — defaults to `JosjobRagpdf.Temp.job_dir(job.id)`
    * `:known_skills` — defaults to `[]`

  Statuses follow `CONTRACT.md`: `:done`, `:partial`, `:unreadable`, `:failed`.
  Error strings are safe for JSON and never contain extracted text or PDF bytes.
  """

  alias JosjobRagpdf.{Job, Jobs, Merge, Result, Temp}

  @default_max_pages 6
  @default_overlap 1

  @spec run(Job.t(), keyword()) :: :ok
  def run(%Job{} = job, opts \\ []) do
    ctx = context(job, opts)

    try do
      case Jobs.update(job.id, %{status: :processing, started_at: DateTime.utc_now()}) do
        {:ok, current} -> process(current, ctx)
        {:error, :not_found} -> :ok
      end
    rescue
      _exception -> fail(job.id, "Internal worker error", [])
    catch
      _kind, _reason -> fail(job.id, "Internal worker error", [])
    after
      cleanup(job.id, ctx.tmp_dir)
    end

    :ok
  end

  defp context(job, opts) do
    %{
      pdf: Keyword.get(opts, :pdf, JosjobRagpdf.Pdf),
      ai: Keyword.get(opts, :ai, JosjobRagpdf.AI),
      http: Keyword.get(opts, :http, JosjobRagpdf.HTTP),
      tmp_dir: Keyword.get(opts, :tmp_dir) || Temp.job_dir(job.id),
      known_skills:
        List.wrap(Keyword.get(opts, :known_skills, Map.get(job, :known_skills) || [])),
      max_pages:
        Keyword.get(
          opts,
          :max_pages_per_request,
          Application.get_env(:josjob_ragpdf, :max_pages_per_request, @default_max_pages)
        ),
      overlap:
        Keyword.get(
          opts,
          :chunk_overlap_pages,
          Application.get_env(:josjob_ragpdf, :chunk_overlap_pages, @default_overlap)
        )
    }
  end

  defp process(job, ctx) do
    case resolve_source(job, ctx) do
      {:ok, path} ->
        extract(job, path, ctx)

      {:error, message} ->
        fail(job.id, message, [])
    end
  end

  defp extract(job, path, ctx) do
    case ctx.pdf.validate(path) do
      :ok ->
        extract_pages(job, path, ctx)

      {:error, reason} ->
        unreadable(job.id, unreadable_message(reason))
    end
  end

  defp extract_pages(job, path, ctx) do
    case ctx.pdf.page_count(path) do
      {:ok, pages} when is_integer(pages) and pages > 0 ->
        extract_chunks(job, path, pages, ctx)

      {:ok, _pages} ->
        unreadable(job.id, "PDF has no pages")

      {:error, _reason} ->
        unreadable(job.id, "PDF page count could not be determined")
    end
  end

  defp extract_chunks(job, path, pages, ctx) do
    ranges =
      case ctx.pdf.chunk_ranges(pages, ctx.max_pages, ctx.overlap) do
        ranges when is_list(ranges) -> ranges
        _ -> []
      end

    total = length(ranges)

    case Jobs.update(job.id, %{pages: pages, chunks_total: total, chunks_done: 0}) do
      {:error, :not_found} ->
        :ok

      _updated ->
        process_ranges(job, path, ranges, total, ctx)
    end
  end

  defp process_ranges(job, path, ranges, total, ctx) do
    {successes, failures} =
      ranges
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {{first, last}, index}, {successes, failures} ->
        outcome = extract_one(job, path, {first, last}, index, total, ctx)

        # Progress moves even when a chunk fails; clients can see liveness.
        Jobs.update(job.id, fn current ->
          %{chunks_done: (current.chunks_done || 0) + 1}
        end)

        case outcome do
          {:ok, result, meta} -> {[{result, meta} | successes], failures}
          {:error, reason} -> {successes, [{index, reason} | failures]}
        end
      end)

    finish(job, Enum.reverse(successes), Enum.reverse(failures))
  end

  defp extract_one(job, path, {first, last}, index, total, ctx) do
    chunk_path = Path.join(ctx.tmp_dir, "chunk-#{index}.pdf")

    outcome =
      case ctx.pdf.split(path, {first, last}, chunk_path) do
        :ok ->
          ai_opts = [
            index: index,
            total: total,
            filename: filename(job, path),
            known_skills: ctx.known_skills
          ]

          case ctx.ai.extract_chunk(chunk_path, ai_opts) do
            {:ok, result, meta} -> {:ok, result, meta}
            {:error, reason} -> {:error, reason}
            _other -> {:error, :invalid_response}
          end

        {:error, reason} ->
          {:error, {:split_failed, reason}}

        _other ->
          {:error, :split_failed}
      end

    # Chunk files are ephemeral. The whole dir is removed in `run/2`'s after
    # block too, but deleting eagerly keeps disk usage bounded.
    _ = File.rm(chunk_path)
    outcome
  end

  defp finish(job, [], failures) do
    finish_update(job.id, %{
      status: :failed,
      error: all_failed_error(failures),
      warnings: chunk_warnings(failures),
      result: nil,
      provider: nil,
      model: nil
    })
  end

  defp finish(job, successes, failures) do
    merged =
      successes
      |> Enum.map(fn {result, _meta} -> result end)
      |> Merge.merge()

    {provider, model} = first_meta(successes)
    warnings = chunk_warnings(failures)

    status =
      cond do
        Result.empty?(merged) -> :partial
        failures != [] -> :partial
        true -> :done
      end

    finish_update(job.id, %{
      status: status,
      result: merged,
      provider: provider,
      model: model,
      warnings: warnings,
      error: nil
    })
  end

  defp unreadable(job_id, message) do
    finish_update(job_id, %{
      status: :unreadable,
      error: message,
      warnings: [],
      result: nil
    })
  end

  defp fail(job_id, message, warnings) do
    finish_update(job_id, %{
      status: :failed,
      error: message,
      warnings: warnings,
      result: nil
    })
  end

  defp finish_update(job_id, attrs) do
    attrs = Map.put(attrs, :finished_at, DateTime.utc_now())

    try do
      Jobs.update(job_id, attrs)
    rescue
      _exception -> {:error, :not_found}
    catch
      _kind, _reason -> {:error, :not_found}
    end
  end

  ## Source resolution

  defp resolve_source(%Job{source: {:upload, path}}, _ctx)
       when is_binary(path) and path != "" do
    {:ok, path}
  end

  defp resolve_source(%Job{source: {:url, url}} = job, ctx)
       when is_binary(url) and url != "" do
    try do
      File.mkdir_p!(ctx.tmp_dir)
      destination = Path.join(ctx.tmp_dir, download_filename(job, url))

      case ctx.http.download(url, destination) do
        :ok -> {:ok, destination}
        _other -> {:error, "Failed to download PDF"}
      end
    rescue
      _exception -> {:error, "Failed to download PDF"}
    catch
      _kind, _reason -> {:error, "Failed to download PDF"}
    end
  end

  defp resolve_source(%Job{source: {:base64, data}} = job, ctx) when is_binary(data) do
    with {:ok, binary} <- decode_base64(data) do
      try do
        File.mkdir_p!(ctx.tmp_dir)
        path = Path.join(ctx.tmp_dir, sanitize_filename(job.filename))
        File.write!(path, binary)
        {:ok, path}
      rescue
        _exception -> {:error, "Could not store PDF data"}
      end
    else
      _error -> {:error, "Invalid base64 PDF data"}
    end
  end

  defp resolve_source(_job, _ctx), do: {:error, "Missing PDF source"}

  defp download_filename(%Job{filename: filename}, _url)
       when is_binary(filename) and filename != "" do
    sanitize_filename(filename)
  end

  defp download_filename(_job, url) do
    name =
      case URI.parse(url) do
        %URI{path: path} when is_binary(path) and path != "" ->
          path |> Path.basename() |> URI.decode()

        _uri ->
          ""
      end

    sanitize_filename(name)
  rescue
    _exception -> "cv.pdf"
  end

  defp decode_base64(data) do
    data = String.trim(data)

    data =
      case Regex.run(~r/^data:[^,]*;base64,/i, data) do
        [prefix] -> binary_part(data, byte_size(prefix), byte_size(data) - byte_size(prefix))
        _no_prefix -> data
      end

    data = String.replace(data, ~r/\s+/, "")

    case Base.decode64(data) do
      {:ok, binary} -> {:ok, binary}
      :error -> Base.decode64(data, padding: false)
    end
  end

  defp sanitize_filename(nil), do: "cv.pdf"

  defp sanitize_filename(name) when is_binary(name) do
    name =
      name
      |> String.trim()
      |> Path.basename()
      |> String.replace(~r/[^A-Za-z0-9._-]+/, "_")

    if name in ["", ".", ".."], do: "cv.pdf", else: name
  end

  defp sanitize_filename(_name), do: "cv.pdf"

  defp filename(%Job{filename: filename}, _path) when is_binary(filename) and filename != "",
    do: filename

  defp filename(_job, path), do: Path.basename(path)

  ## Result helpers

  defp first_meta([{_result, meta} | _rest]) when is_map(meta) do
    {meta_value(meta, :provider), meta_value(meta, :model)}
  end

  defp first_meta([_other | rest]), do: first_meta(rest)
  defp first_meta([]), do: {nil, nil}

  defp meta_value(meta, key) do
    string_value(Map.get(meta, key) || Map.get(meta, Atom.to_string(key)))
  end

  defp string_value(nil), do: nil
  defp string_value(value) when is_binary(value), do: value
  defp string_value(value) when is_atom(value), do: Atom.to_string(value)
  defp string_value(_value), do: nil

  defp chunk_warnings(failures) do
    Enum.map(failures, fn {index, _reason} -> "Chunk #{index} failed" end)
  end

  defp all_failed_error(failures) do
    case failures do
      [] ->
        "All chunks failed"

      _ ->
        details =
          failures
          |> Enum.map(fn {index, reason} -> "chunk #{index}: #{safe_reason(reason)}" end)
          |> Enum.join("; ")

        "All chunks failed (" <> details <> ")"
    end
  end

  defp safe_reason(:timeout), do: "timeout"
  defp safe_reason(:not_configured), do: "not configured"
  defp safe_reason(:no_text), do: "no text"
  defp safe_reason(:invalid_response), do: "invalid response"
  defp safe_reason(:split_failed), do: "could not split PDF"
  defp safe_reason({:split_failed, _reason}), do: "could not split PDF"
  defp safe_reason({:all_providers_failed, _attempts}), do: "all providers failed"
  defp safe_reason(_reason), do: "extraction error"

  defp unreadable_message(:not_found), do: "PDF file not found"
  defp unreadable_message(:not_pdf), do: "File is not a valid PDF"
  defp unreadable_message(:empty), do: "PDF file is empty"
  defp unreadable_message(_reason), do: "PDF is not readable"

  ## Cleanup

  defp cleanup(job_id, tmp_dir) do
    Temp.cleanup(job_id)

    if tmp_dir != Temp.job_dir(job_id) do
      File.rm_rf(tmp_dir)
    end

    :ok
  end
end
