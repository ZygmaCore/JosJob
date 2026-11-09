defmodule StellarWeb.MyDocumentLive do
  @moduledoc """
  Portal `/my/documents` versi LiveView: user login melihat dokumen `visible_to`
  dirinya (miliknya + se-org bila ia admin-org + yang di-share) dan
  mengunggah/menghapus miliknya. Dokumen = record metadata (title + File URL).
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias StellarDoc.Documents
  alias StellarDoc.Documents.Document
  alias Stellar.Orgs.{Membership, Organization}

  @doc "Label jenis dokumen dari course_id (course vs user)."
  def kind(%{course_id: nil}), do: "user"
  def kind(_), do: "course"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> load_documents()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    form = AshPhoenix.Form.for_create(Document, :create, as: "document", authorize?: false)

    socket
    |> assign(:form, to_form(form))
    |> assign(:org_options, my_org_options(socket.assigns.current_user))
  end

  @impl true
  def handle_event("validate", %{"document" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"document" => params}, socket) do
    params =
      params |> normalize() |> Map.put("user_id", socket.assigns.current_user.id)

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _doc} ->
        {:noreply,
         socket
         |> put_flash(:info, "Document uploaded.")
         |> push_patch(to: ~p"/my/documents")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    doc = Ash.get!(Document, id, authorize?: false)

    if can_delete?(user, doc) do
      Ash.destroy!(doc, authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Document deleted.")
       |> load_documents()}
    else
      {:noreply, put_flash(socket, :error, "You can't delete this document.")}
    end
  end

  # Boleh hapus: superuser, pemilik, atau admin-org dari org dokumen.
  defp can_delete?(%{is_superuser: true}, _doc), do: true
  defp can_delete?(%{id: uid}, %{user_id: uid}), do: true

  defp can_delete?(%{id: uid}, %{organization_id: org_id}),
    do: org_id in Documents.admin_org_ids(uid)

  defp load_documents(socket) do
    socket
    |> assign(:documents, Documents.visible_to(socket.assigns.current_user))
    |> assign(:owner_names, StellarWeb.Audit.user_labels())
    |> assign(:org_names, org_name_map())
  end

  defp normalize(params) do
    Enum.reduce(["course_id", "mime_type", "description"], params, fn key, acc ->
      if Map.get(acc, key) in ["", nil], do: Map.put(acc, key, nil), else: acc
    end)
  end

  # Organisasi tempat user jadi member aktif (opsi tenant saat upload).
  defp my_org_options(%{id: uid}) do
    Membership
    |> Ash.Query.filter(user_id == ^uid and status == :active)
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:organization], authorize?: false)
    |> Enum.map(&{&1.organization.name, &1.organization_id})
    |> Enum.uniq()
  end

  defp my_org_options(_), do: []

  defp org_name_map,
    do: Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:my_documents}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        My Documents
        <:subtitle>Documents you own (and org-wide if you're an org admin).</:subtitle>
        <:actions>
          <.link patch={~p"/my/documents/new"}>
            <.button variant="primary">Upload document</.button>
          </.link>
        </:actions>
      </.header>

      <.table id="my-documents" rows={@documents}>
        <:col :let={d} label="Title">{d.title}</:col>
        <:col :let={d} label="Type">
          <span class="badge badge-neutral">{kind(d)}</span>
        </:col>
        <:col :let={d} label="Owner">{@owner_names[d.user_id] || "-"}</:col>
        <:col :let={d} label="Organization">{@org_names[d.organization_id] || "-"}</:col>
        <:col :let={d} label="Mime">{d.mime_type}</:col>
        <:col :let={d} label="URL">
          <a href={d.url} target="_blank" class="link">open</a>
        </:col>
        <:action :let={d}>
          <.link
            phx-click="delete"
            phx-value-id={d.id}
            data-confirm={"Delete document #{d.title}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@live_action == :new} id="my-document-modal" class="modal modal-open">
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">Upload document</h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:title]} type="text" label="Title" required />
            <.input field={@form[:url]} type="text" label="File URL" required />
            <.input field={@form[:mime_type]} type="text" label="Mime type (e.g. application/pdf)" />
            <.input field={@form[:description]} type="textarea" label="Description" rows="2" />
            <.input
              field={@form[:organization_id]}
              type="select"
              label="Organization"
              options={@org_options}
              prompt="— Select organization —"
              required
            />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Uploading...">Upload</.button>
              <.link patch={~p"/my/documents"} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={~p"/my/documents"} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
