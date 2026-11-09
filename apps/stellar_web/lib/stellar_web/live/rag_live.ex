defmodule StellarWeb.RagLive do
  use StellarWeb, :live_view

  require Logger

  alias StellarRag.AtomicClient
  alias StellarRag.Indexer

  @supported_extensions ~w(.pdf .docx .doc .pptx .ppt .xlsx .xls .txt .md .html .csv .json)

  @impl true
  def mount(_params, _session, socket) do
    # Load user
    current_user = socket.assigns[:current_user]

    # Verify user exists and is member
    if current_user do
      courses = fetch_courses()
      first_course_id = List.first(courses) && List.first(courses).id

      socket =
        socket
        |> assign(:courses, courses)
        |> assign(:selected_course_id, first_course_id)
        |> assign(:visibility, "private")
        |> assign(:documents, [])
        |> assign(:error_message, nil)
        |> assign(:success_message, nil)
        |> assign_documents_for_course(first_course_id)
        |> allow_upload(:documents,
          accept: @supported_extensions,
          max_entries: 5,
          # 10MB
          max_file_size: 10_000_000
        )

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event(
        "validate",
        %{"selected_course_id" => course_id, "visibility" => visibility},
        socket
      ) do
    # Simply update the state on change
    socket =
      socket
      |> assign(:selected_course_id, course_id)
      |> assign(:visibility, visibility)
      |> assign_documents_for_course(course_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_course", %{"course_id" => course_id}, socket) do
    socket =
      socket
      |> assign(:selected_course_id, course_id)
      |> assign_documents_for_course(course_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    course_id = socket.assigns.selected_course_id
    user_id = socket.assigns.current_user.id

    if is_nil(course_id) do
      {:noreply, assign(socket, :error_message, "Please select a course before uploading.")}
    else
      uploaded_results =
        consume_uploaded_entries(socket, :documents, fn path, entry ->
          filename = entry.client_name

          case Indexer.ingest(path, filename, course_id, user_id) do
            {:ok, _response} ->
              {:ok, {:ok, filename}}

            {:error, reason} ->
              {:ok, {:error, filename, reason}}
          end
        end)

      # Check for successes and failures
      successes = Enum.filter(uploaded_results, &match?({:ok, _}, &1))
      failures = Enum.filter(uploaded_results, &match?({:error, _, _}, &1))

      {success_msg, error_msg} =
        cond do
          length(failures) > 0 ->
            fail_details = Enum.map_join(failures, ", ", fn {:error, f, _} -> f end)
            {nil, "Failed to upload document(s): #{fail_details}."}

          length(successes) > 0 ->
            succ_details = Enum.map_join(successes, ", ", fn {:ok, f} -> f end)
            {"Successfully uploaded and indexed: #{succ_details}.", nil}

          true ->
            {nil, nil}
        end

      socket =
        socket
        |> assign(:success_message, success_msg)
        |> assign(:error_message, error_msg)
        |> assign_documents_for_course(course_id)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_document", %{"id" => atom_id}, socket) do
    course_id = socket.assigns.selected_course_id
    user_id = socket.assigns.current_user.id
    org_id = Indexer.get_user_organization_id(user_id)
    db_id = "db_#{org_id}_#{course_id}"

    case AtomicClient.delete_atom(db_id, atom_id) do
      {:ok, _} ->
        socket =
          socket
          |> assign(:success_message, "Document deleted successfully.")
          |> assign(:error_message, nil)
          |> assign_documents_for_course(course_id)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         assign(socket, :error_message, "Failed to delete document: #{inspect(reason)}")}
    end
  end

  # Helper to query courses
  defp fetch_courses do
    StellarLrn.Learning.Course
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.title)
  rescue
    _ -> []
  end

  # Helper to assign documents from Atomic Server for the selected course
  defp assign_documents_for_course(socket, nil), do: assign(socket, :documents, [])

  defp assign_documents_for_course(socket, course_id) do
    user_id = socket.assigns.current_user.id
    org_id = Indexer.get_user_organization_id(user_id)
    db_id = "db_#{org_id}_#{course_id}"

    documents =
      case AtomicClient.list_atoms(db_id) do
        {:ok, list} when is_list(list) ->
          Enum.map(list, fn
            %{"id" => id, "title" => title} = map ->
              %{
                id: id,
                title: title,
                created_at: Map.get(map, "created_at", "N/A"),
                size: get_content_size(Map.get(map, "content", ""))
              }

            _ ->
              nil
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, %{"atoms" => list}} when is_list(list) ->
          Enum.map(list, fn
            %{"id" => id, "title" => title} = map ->
              %{
                id: id,
                title: title,
                created_at: Map.get(map, "created_at", "N/A"),
                size: get_content_size(Map.get(map, "content", ""))
              }

            _ ->
              nil
          end)
          |> Enum.reject(&is_nil/1)

        _ ->
          []
      end

    assign(socket, :documents, documents)
  end

  defp get_content_size(content) when is_binary(content) do
    bytes = byte_size(content)

    cond do
      bytes > 1_024 * 1_024 -> "#{Float.round(bytes / (1_024 * 1_024), 2)} MB"
      bytes > 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{bytes} Bytes"
    end
  end

  defp get_content_size(_), do: "0 Bytes"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} active={:rag}>
      <div class="space-y-6">
        <!-- Header Section -->
        <div class="card bg-base-200 shadow-xl border border-base-300">
          <div class="card-body">
            <div class="flex items-center gap-3">
              <div class="p-3 bg-primary/10 rounded-xl text-primary">
                <.icon name="hero-cpu-chip" class="size-8" />
              </div>
              <div>
                <h1 class="text-2xl font-bold tracking-tight">RAG Ingestion Center</h1>
                <p class="text-base-content/75 text-sm">
                  Upload learning materials to your course's vector library hosted on the Atomic Server.
                </p>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Alert messages -->
        <div :if={@success_message} class="alert alert-success shadow-lg">
          <.icon name="hero-check-circle" class="size-6 text-success-content" />
          <span>{@success_message}</span>
        </div>

        <div :if={@error_message} class="alert alert-error shadow-lg">
          <.icon name="hero-x-circle" class="size-6 text-error-content" />
          <span>{@error_message}</span>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Ingestion Form Card -->
          <div class="lg:col-span-1 space-y-6">
            <div class="card bg-base-100 border border-base-300 shadow-xl">
              <div class="card-body space-y-4">
                <h2 class="card-title text-lg font-bold border-b border-base-300 pb-2">
                  1. Configure Ingestion
                </h2>

                <form id="rag-config-form" phx-change="validate" phx-submit="save" class="space-y-4">
                  <!-- Course Dropdown -->
                  <div class="form-control">
                    <label class="label font-semibold text-xs text-base-content/75">
                      Target Course
                    </label>
                    <select
                      name="selected_course_id"
                      class="select select-bordered w-full"
                      id="course-select"
                    >
                      <option :if={Enum.empty?(@courses)} value="">No courses available</option>
                      <option
                        :for={course <- @courses}
                        value={course.id}
                        selected={@selected_course_id == course.id}
                      >
                        {course.title}
                      </option>
                    </select>
                  </div>
                  
    <!-- Visibility Selector -->
                  <div class="form-control">
                    <label class="label font-semibold text-xs text-base-content/75">
                      Vector Visibility
                    </label>
                    <select
                      name="visibility"
                      class="select select-bordered w-full"
                      id="visibility-select"
                    >
                      <option value="private" selected={@visibility == "private"}>
                        Private (Enrolled Students)
                      </option>
                      <option value="public" selected={@visibility == "public"}>
                        Public (All Members)
                      </option>
                      <option value="published" selected={@visibility == "published"}>
                        Published (Everyone)
                      </option>
                    </select>
                  </div>
                  
    <!-- Upload drop area -->
                  <div class="form-control pt-2">
                    <label class="label font-semibold text-xs text-base-content/75">
                      Upload Materials
                    </label>
                    <div
                      class="flex flex-col items-center justify-center border-2 border-dashed border-base-300 hover:border-primary/50 transition-colors rounded-xl p-6 bg-base-200/50 cursor-pointer group"
                      phx-drop-target={@uploads.documents.ref}
                    >
                      <.icon
                        name="hero-arrow-up-tray"
                        class="size-8 text-base-content/50 group-hover:text-primary transition-colors mb-2"
                      />
                      <span class="text-xs font-semibold text-base-content/85 mb-1 text-center">
                        Drag and drop files here or click to browse
                      </span>
                      <span class="text-[10px] text-base-content/50">
                        Supports PDF, Word, slides, spreadsheet, and text files
                      </span>
                      <.live_file_input upload={@uploads.documents} class="hidden" />
                    </div>
                  </div>
                  
    <!-- Ingestion Progress / Preview -->
                  <div
                    :for={entry <- @uploads.documents.entries}
                    class="text-xs space-y-1 bg-base-200 p-2 rounded-lg border border-base-300"
                  >
                    <div class="flex justify-between font-semibold">
                      <span class="truncate max-w-[200px]">{entry.client_name}</span>
                      <span>{entry.progress}%</span>
                    </div>
                    <progress
                      class="progress progress-primary w-full"
                      value={entry.progress}
                      max="100"
                    >
                    </progress>
                    <div
                      :for={err <- upload_errors(@uploads.documents, entry)}
                      class="text-error text-[10px]"
                    >
                      {inspect(err)}
                    </div>
                  </div>
                  
    <!-- Submit Ingestion -->
                  <button
                    type="submit"
                    class="btn btn-primary w-full gap-2 mt-4"
                    disabled={Enum.empty?(@uploads.documents.entries) or is_nil(@selected_course_id)}
                    id="submit-ingest-button"
                  >
                    <.icon name="hero-document-magnifying-glass" class="size-4" /> Start Ingestion
                  </button>
                </form>
              </div>
            </div>
          </div>
          
    <!-- Document List Card -->
          <div class="lg:col-span-2">
            <div class="card bg-base-100 border border-base-300 shadow-xl min-h-[350px]">
              <div class="card-body">
                <div class="flex justify-between items-center border-b border-base-300 pb-2">
                  <h2 class="card-title text-lg font-bold">
                    2. Ingested Atoms
                  </h2>
                  <span class="badge badge-neutral text-xs">
                    {length(@documents)} Files
                  </span>
                </div>
                
    <!-- Empty State -->
                <div
                  :if={Enum.empty?(@documents)}
                  class="flex flex-col items-center justify-center py-16 text-center space-y-3"
                >
                  <div class="p-4 bg-base-200 rounded-full text-base-content/40">
                    <.icon name="hero-folder-open" class="size-12" />
                  </div>
                  <div>
                    <h3 class="font-bold text-base-content/80">No documents ingested</h3>
                    <p class="text-xs text-base-content/50 max-w-xs mt-1">
                      Choose a course and upload learning materials to build your semantic knowledge graph.
                    </p>
                  </div>
                </div>
                
    <!-- Table -->
                <div :if={not Enum.empty?(@documents)} class="overflow-x-auto mt-4">
                  <table class="table table-zebra w-full text-sm">
                    <thead>
                      <tr>
                        <th class="bg-base-200">Filename</th>
                        <th class="bg-base-200">Content Size</th>
                        <th class="bg-base-200">Ingested At</th>
                        <th class="bg-base-200 text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={doc <- @documents} class="hover">
                        <td class="font-medium truncate max-w-[250px]">
                          <div class="flex items-center gap-2">
                            <.icon name="hero-document" class="size-4 text-primary" />
                            {doc.title}
                          </div>
                        </td>
                        <td>{doc.created_at}</td>
                        <td>{doc.size}</td>
                        <td class="text-right">
                          <button
                            class="btn btn-ghost btn-xs text-error hover:bg-error/10"
                            phx-click="delete_document"
                            phx-value-id={doc.id}
                            data-confirm="Are you sure you want to delete this document from the Atomic RAG knowledge graph?"
                          >
                            <.icon name="hero-trash" class="size-4" />
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
