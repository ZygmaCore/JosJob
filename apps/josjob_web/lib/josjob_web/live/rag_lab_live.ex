defmodule JosjobWeb.RagLabLive do
  @moduledoc """
  Lab live-test pipeline RAG: unggah PDF CV → ekstraksi terstruktur
  (`josjob_ragpdf`) → ranking job deterministik + rekomendasi course.

  Halaman ini memanggil modul yang sama dengan API JSON, tapi in-process
  supaya bisa diuji dari browser tanpa Bearer token:

      POST /api/rag/cv/extractions      -> PdfClient.submit_upload/4
      GET  /api/rag/cv/extractions/:id  -> PdfClient.get/2 (polling)
      POST /api/rag/analyses            -> Analyzer.analyze/3

  Hasil tidak dipersist; ini alat uji, bukan alur produksi.
  """

  use JosjobWeb, :live_view

  require Logger

  alias JosjobRag.{Analyzer, PdfClient, Text}

  @poll_interval 2_000
  @max_polls 150
  @max_file_size 10_000_000
  @accept ~w(.pdf)
  @limit 10

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:ok, redirect(socket, to: ~p"/")}

      user ->
        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:step, :idle)
         |> assign(:extraction, nil)
         |> assign(:result, nil)
         |> assign(:error, nil)
         |> assign(:polls, 0)
         |> allow_upload(:cv,
           accept: @accept,
           max_entries: 1,
           max_file_size: @max_file_size
         )}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  def handle_event("extract", _params, %{assigns: %{step: step}} = socket)
      when step in [:extracting, :analyzing] do
    {:noreply, socket}
  end

  def handle_event("extract", _params, socket) do
    case uploaded_entries(socket, :cv) do
      {[_ | _], []} -> start_extraction(socket)
      _ -> {:noreply, assign(socket, :error, "Pilih satu file PDF CV dulu.")}
    end
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cv, ref)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :idle)
     |> assign(:extraction, nil)
     |> assign(:result, nil)
     |> assign(:error, nil)
     |> assign(:polls, 0)
     |> allow_upload(:cv,
       accept: @accept,
       max_entries: 1,
       max_file_size: @max_file_size
     )}
  end

  @impl true
  def handle_info({:poll, id}, socket) do
    extraction = socket.assigns.extraction

    if (socket.assigns.step == :extracting and extraction) && extraction.id == id do
      poll(socket, id)
    else
      {:noreply, socket}
    end
  end

  # --- extraction ---------------------------------------------------------

  defp start_extraction(socket) do
    user = socket.assigns.user
    cv_id = "lab-#{System.system_time(:second)}-#{System.unique_integer([:positive])}"

    results =
      consume_uploaded_entries(socket, :cv, fn %{path: path}, entry ->
        upload = %{path: path, filename: entry.client_name, content_type: entry.client_type}

        # consume_uploaded_entries/3 melepas `{:ok, value}` dan mengembalikan
        # `value` saja, jadi bungkus hasil client supaya statusnya eksplisit.
        {:ok, pdf_client().submit_upload(upload, user.id, cv_id)}
      end)

    case results do
      [{:ok, %{"data" => %{"id" => id} = data}}] ->
        {:noreply,
         socket
         |> assign(:step, :extracting)
         |> assign(:error, nil)
         |> assign(:polls, 0)
         |> assign(:extraction, %{
           id: id,
           cv_id: data["cv_id"] || cv_id,
           filename: data["filename"],
           status: data["status"] || "queued",
           pages: nil,
           progress: nil,
           chunks_done: nil,
           chunks_total: nil,
           queue_position: data["queue_position"]
         })
         |> schedule_poll(id)}

      [{:ok, body}] ->
        fail(socket, "Respons tak terduga dari layanan ekstraksi: #{inspect(body, limit: 3)}")

      [{:error, reason}] ->
        fail(socket, "Gagal mengirim PDF: #{inspect(reason)}")

      _ ->
        fail(socket, "Tidak ada file yang diunggah.")
    end
  end

  defp schedule_poll(socket, id) do
    _ = Process.send_after(self(), {:poll, id}, poll_interval())
    socket
  end

  defp poll(socket, id) do
    case pdf_client().get(id) do
      {:ok, %{"data" => data}} ->
        case data["status"] do
          status when status in ["done", "partial"] ->
            analyze(socket, data)

          status when status in ["failed", "unreadable"] ->
            fail(socket, data["error"] || "Ekstraksi gagal (#{status}).")

          status ->
            wait(socket, id, status, data)
        end

      {:ok, body} ->
        fail(socket, "Respons tak terduga dari layanan ekstraksi: #{inspect(body, limit: 3)}")

      {:error, reason} ->
        fail(socket, "Gagal memeriksa status ekstraksi: #{inspect(reason)}")
    end
  end

  defp wait(socket, id, status, data) do
    polls = socket.assigns.polls + 1
    timeout_minutes = div(@max_polls * @poll_interval, 60_000)

    if polls > @max_polls do
      fail(socket, "Ekstraksi belum selesai setelah #{timeout_minutes} menit.")
    else
      extraction =
        Map.merge(socket.assigns.extraction, %{
          status: status,
          progress: data["progress"],
          pages: data["pages"],
          chunks_done: data["chunks_done"],
          chunks_total: data["chunks_total"],
          queue_position: data["queue_position"]
        })

      {:noreply,
       socket
       |> assign(:polls, polls)
       |> assign(:extraction, extraction)
       |> schedule_poll(id)}
    end
  end

  # --- ranking ------------------------------------------------------------

  defp analyze(socket, data) do
    result = data["result"] || %{}
    extraction = socket.assigns.extraction

    cv = %{
      "cv_id" => extraction.cv_id,
      "skills" => as_list(result["skills"]),
      "experience" => as_list(result["experience"]),
      "education" => as_list(result["education"])
    }

    # Hasil ekstraksi memberi skill sebagai map (`%{"name" => ..., "confidence" => ...}`).
    # Untuk tampilan pakai normalisasi yang sama dengan ranker supaya labelnya
    # konsisten dengan skor yang dihitung.
    cv_skills = Text.requirement_list(cv["skills"])

    socket =
      socket
      |> assign(:step, :analyzing)
      |> assign(:extraction, %{
        extraction
        | status: "done",
          pages: data["pages"],
          progress: 1.0,
          chunks_done: data["chunks_done"],
          chunks_total: data["chunks_total"]
      })

    case analyzer().analyze(socket.assigns.user, cv, limit: @limit) do
      {:ok, analysis} ->
        {:noreply,
         socket
         |> assign(:step, :done)
         |> assign(:result, analysis |> Map.put(:cv, cv) |> Map.put(:cv_skills, cv_skills))}

      {:error, reason} ->
        fail(socket, "Gagal menganalisis CV: #{inspect(reason)}")
    end
  end

  defp fail(socket, message) do
    {:noreply,
     socket
     |> assign(:step, :error)
     |> assign(:error, to_string(message))}
  end

  defp as_list(value) when is_list(value), do: value
  defp as_list(_value), do: []

  # --- dependencies (overridable di test) ---------------------------------

  defp pdf_client, do: Application.get_env(:josjob_web, :rag_lab_pdf_client, PdfClient)
  defp analyzer, do: Application.get_env(:josjob_web, :rag_lab_analyzer, Analyzer)
  defp poll_interval, do: Application.get_env(:josjob_web, :rag_lab_poll_interval, @poll_interval)

  # --- render helpers -----------------------------------------------------

  defp pct(nil), do: "0%"

  defp pct(value) when is_float(value), do: "#{Float.round(value * 100, 1)}%"
  defp pct(value) when is_integer(value), do: "#{value}%"
  defp pct(_value), do: "0%"

  defp score_number(nil), do: "0.00"
  defp score_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp score_number(value), do: to_string(value)

  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 1_000_000,
    do: "#{Float.round(bytes / 1_000_000, 1)} MB"

  defp format_bytes(bytes) when is_integer(bytes), do: "#{div(bytes, 1000)} KB"
  defp format_bytes(_bytes), do: ""

  defp job_field(job, key), do: Map.get(job, key)

  defp company(job) do
    case Map.get(job, :organization) do
      %{name: name} when is_binary(name) -> name
      _ -> Map.get(job, :company)
    end
  end

  defp step_label(:extracting), do: "Mengekstrak CV (Gemini Vision)"
  defp step_label(:analyzing), do: "Menghitung embedding & ranking"
  defp step_label(:done), do: "Selesai"
  defp step_label(_step), do: "Menunggu"

  defp status_text(%{status: "queued", queue_position: position}) when is_integer(position),
    do: "Dalam antrean (posisi #{position})."

  defp status_text(%{status: "processing"} = extraction),
    do: "Memproses halaman #{page_progress(extraction)}."

  defp status_text(_extraction), do: "Menunggu hasil ekstraksi."

  defp page_progress(%{chunks_done: done, chunks_total: total})
       when is_integer(done) and is_integer(total) and total > 0,
       do: "chunk #{done}/#{total}"

  defp page_progress(%{pages: pages}) when is_integer(pages), do: "#{pages} halaman"
  defp page_progress(_extraction), do: "…"

  defp error_to_string(:too_large), do: "File terlalu besar (maksimal 10 MB)."
  defp error_to_string(:too_many_files), do: "Hanya satu file yang boleh diunggah."
  defp error_to_string(:not_accepted), do: "Hanya file .pdf yang diterima."
  defp error_to_string(error), do: "Upload gagal: #{inspect(error)}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} active={:rag_lab}>
      <div class="space-y-6">
        <div class="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold tracking-tight">RAG Lab</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Unggah PDF CV → ekstraksi Gemini → ranking job + rekomendasi course.
              Pipeline asli (`josjob_ragpdf` + Gemini embeddings + pgvector).
            </p>
          </div>
          <button
            :if={@step != :idle}
            type="button"
            phx-click="reset"
            class="btn btn-ghost btn-sm"
            id="rag-lab-reset"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Mulai ulang
          </button>
        </div>

        <div class="rounded-2xl border border-base-300 bg-base-100 p-5 shadow-sm">
          <.form
            for={%{}}
            as={:lab}
            id="rag-lab-form"
            phx-change="validate"
            phx-submit="extract"
            class="space-y-4"
          >
            <div
              class="flex flex-col items-center justify-center gap-3 rounded-xl border-2 border-dashed border-base-300 bg-base-200/40 px-6 py-8 text-center transition hover:border-primary/60 hover:bg-primary/5"
              phx-drop-target={@uploads.cv.ref}
            >
              <.icon name="hero-document-arrow-up" class="size-9 text-primary" />
              <div>
                <p class="font-medium">Tarik PDF CV ke sini, atau pilih file</p>
                <p class="text-xs text-base-content/60">Maksimal 10 MB · hanya .pdf</p>
              </div>
              <.live_file_input
                upload={@uploads.cv}
                class="file-input file-input-bordered w-full max-w-sm"
              />
            </div>

            <%= for entry <- @uploads.cv.entries do %>
              <div class="flex items-center justify-between rounded-lg bg-base-200 px-3 py-2 text-sm">
                <div class="flex min-w-0 items-center gap-2">
                  <.icon name="hero-document-text" class="size-4 shrink-0" />
                  <span class="truncate font-medium">{entry.client_name}</span>
                  <span class="shrink-0 text-base-content/60">{format_bytes(entry.client_size)}</span>
                </div>
                <button
                  type="button"
                  phx-click="cancel"
                  phx-value-ref={entry.ref}
                  class="btn btn-ghost btn-xs"
                >
                  Batal
                </button>
              </div>
              <%= for error <- upload_errors(@uploads.cv, entry) do %>
                <p class="text-sm text-error">{error_to_string(error)}</p>
              <% end %>
            <% end %>

            <%= for error <- upload_errors(@uploads.cv) do %>
              <p class="text-sm text-error">{error_to_string(error)}</p>
            <% end %>

            <div class="flex flex-wrap items-center justify-between gap-3">
              <p class="text-xs text-base-content/60">
                PDF diproses di service <code class="text-xs">josjob_ragpdf</code> (:4010).
                Hasil lab ini tidak disimpan ke database.
              </p>
              <button
                type="submit"
                id="rag-lab-submit"
                class="btn btn-primary"
                disabled={@step in [:extracting, :analyzing]}
              >
                <.icon name="hero-sparkles" class="size-4" /> Analisis CV
              </button>
            </div>
          </.form>
        </div>

        <div :if={@error} class="alert alert-error text-sm" id="rag-lab-error">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <span>{@error}</span>
        </div>

        <div
          :if={@step in [:extracting, :analyzing]}
          class="rounded-2xl border border-primary/30 bg-primary/5 p-5"
          id="rag-lab-progress"
        >
          <div class="flex items-center gap-3">
            <span class="loading loading-spinner loading-sm text-primary"></span>
            <div>
              <p class="font-medium">{step_label(@step)}</p>
              <p class="text-sm text-base-content/70">
                {if @step == :extracting,
                  do: status_text(@extraction),
                  else: "Mengambil kandidat job, menghitung cosine similarity, lalu menyusun skor."}
              </p>
            </div>
          </div>
        </div>

        <%= if @result do %>
          <div class="flex flex-wrap items-center gap-2 text-xs" id="rag-lab-meta">
            <span class={[
              "badge gap-1",
              @result.semantic && "badge-success",
              !@result.semantic && "badge-warning"
            ]}>
              <.icon name="hero-bolt" class="size-3" />
              {if @result.semantic, do: "semantic ranking aktif", else: "fallback tanpa embedding"}
            </span>
            <span class="badge badge-ghost">{@result.provider || "-"} / {@result.model || "-"}</span>
            <span class="badge badge-ghost">{@result.dimensions || 0} dim</span>
            <span class="badge badge-ghost">{length(@result.jobs)} job</span>
            <span class="badge badge-ghost">{length(@result.cv_skills)} skill terdeteksi</span>
          </div>

          <div class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-base-content/60">
              Skill dari CV
            </p>
            <div class="mt-2 flex flex-wrap gap-1.5">
              <%= for skill <- @result.cv_skills do %>
                <span class="badge badge-outline badge-sm">{skill}</span>
              <% end %>
            </div>
          </div>

          <div
            :if={@result.jobs == []}
            class="rounded-2xl border border-dashed border-base-300 p-8 text-center text-sm text-base-content/60"
          >
            Tidak ada job yang cocok. Pastikan data job sudah di-index (POST /api/rag/reindex).
          </div>

          <div class="space-y-3" id="rag-lab-results">
            <%= for {item, index} <- Enum.with_index(@result.jobs, 1) do %>
              <article class="rounded-2xl border border-base-300 bg-base-100 p-5 shadow-sm transition hover:border-primary/40 hover:shadow-md">
                <div class="flex items-start gap-4">
                  <div class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-sm font-bold text-primary">
                    #{index}
                  </div>

                  <div class="min-w-0 flex-1 space-y-3">
                    <div class="flex flex-wrap items-start justify-between gap-2">
                      <div class="min-w-0">
                        <h2 class="truncate font-semibold">
                          {job_field(item.job, :title) || "Untitled"}
                        </h2>
                        <p class="text-sm text-base-content/70">
                          {company(item.job) || "—"}
                          <span :if={job_field(item.job, :location)}>
                            · {job_field(item.job, :location)}
                          </span>
                        </p>
                      </div>
                      <div class="text-right">
                        <p class="text-lg font-bold text-primary">{pct(item.match_score)}</p>
                        <p class="text-[11px] uppercase tracking-wide text-base-content/50">
                          match score
                        </p>
                      </div>
                    </div>

                    <div class="h-1.5 w-full overflow-hidden rounded-full bg-base-200">
                      <div
                        class="h-full rounded-full bg-primary transition-all"
                        style={"width: #{pct(item.match_score)}"}
                      >
                      </div>
                    </div>

                    <div class="grid grid-cols-3 gap-2 text-center">
                      <div class="rounded-lg bg-base-200/70 px-2 py-1.5">
                        <p class="text-[11px] uppercase tracking-wide text-base-content/50">
                          semantic
                        </p>
                        <p class="text-sm font-semibold">{score_number(item.semantic_score)}</p>
                      </div>
                      <div class="rounded-lg bg-base-200/70 px-2 py-1.5">
                        <p class="text-[11px] uppercase tracking-wide text-base-content/50">skill</p>
                        <p class="text-sm font-semibold">{score_number(item.skill_score)}</p>
                      </div>
                      <div class="rounded-lg bg-base-200/70 px-2 py-1.5">
                        <p class="text-[11px] uppercase tracking-wide text-base-content/50">
                          recency
                        </p>
                        <p class="text-sm font-semibold">{score_number(item.recency_score)}</p>
                      </div>
                    </div>

                    <div class="flex flex-wrap gap-1.5">
                      <%= for skill <- item.matched_skills do %>
                        <span class="badge badge-success badge-sm gap-1">
                          <.icon name="hero-check" class="size-3" /> {skill}
                        </span>
                      <% end %>
                      <%= for skill <- item.missing_skills do %>
                        <span class="badge badge-warning badge-sm gap-1">
                          <.icon name="hero-plus" class="size-3" /> {skill}
                        </span>
                      <% end %>
                    </div>

                    <p class="text-sm text-base-content/70">{item.explanation}</p>

                    <div
                      :if={item.course}
                      class="rounded-xl border border-success/30 bg-success/5 p-3"
                    >
                      <p class="text-[11px] font-medium uppercase tracking-wide text-success">
                        Course yang menutup gap
                      </p>
                      <p class="text-sm font-semibold">{item.course.title}</p>
                      <p class="text-xs text-base-content/60">
                        {Enum.join(item.course.matched_skills, ", ")} · coverage {pct(
                          item.course.coverage
                        )}
                      </p>
                    </div>
                  </div>
                </div>
              </article>
            <% end %>
          </div>

          <div :if={@result.courses != []} class="rounded-2xl border border-base-300 bg-base-100 p-5">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
              Rekomendasi course
            </h2>
            <ul class="mt-3 space-y-2">
              <%= for course <- @result.courses do %>
                <li class="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-base-200/60 px-3 py-2">
                  <div>
                    <p class="text-sm font-medium">{course.title}</p>
                    <p class="text-xs text-base-content/60">
                      {Enum.join(course.matched_skills, ", ")}
                    </p>
                  </div>
                  <span class="badge badge-primary badge-sm">{pct(course.coverage)} coverage</span>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
    </Layouts.admin>
    """
  end
end
