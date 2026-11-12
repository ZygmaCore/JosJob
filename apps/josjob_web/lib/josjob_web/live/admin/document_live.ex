defmodule JosjobWeb.Admin.DocumentLive do
  @moduledoc """
  Menu admin Documents (bank dokumen, RBAC `documents:manage`) versi LiveView.
  Superuser lihat/kelola SEMUA dokumen + filter per org (state URL);
  non-superuser hanya dokumen org aktifnya (create dikunci ke org itu + dirinya).
  Dokumen = record metadata (title + File URL) — upload fisik lewat API.
  """
  use JosjobWeb, :live_view

  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Orgs.Organization
  alias JosjobDoc.Documents.Document

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]

  @doc "Label jenis dokumen dari course_id (course vs user)."
  def kind(%{course_id: nil}), do: "user"
  def kind(_), do: "course"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    org_id = params |> Map.get("organization_id", "") |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:organization_id, org_id)
     |> load_documents()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    form = AshPhoenix.Form.for_create(Document, :create, as: "document", authorize?: false)

    socket
    |> assign(:form, to_form(form))
    |> assign(:user_options, user_options(socket))
    |> assign(:org_form_options, org_options(socket))
  end

  @impl true
  def handle_event("filter", %{"organization_id" => org_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(org_id))}
  end

  def handle_event("validate", %{"document" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"document" => params}, socket) do
    params = params |> normalize() |> put_scope(socket)

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _doc} ->
        {:noreply,
         socket
         |> put_flash(:info, "Document created.")
         |> push_patch(to: index_path(socket.assigns.organization_id))}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    doc = Ash.get!(Document, id, authorize?: false)

    if su?(socket) or doc.organization_id == active_org(socket) do
      Ash.destroy!(doc, authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Document deleted.")
       |> load_documents()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  defp load_documents(socket) do
    documents =
      base_scope(socket)
      |> Ash.Query.sort(created_at: :desc)
      |> maybe_filter_org(socket)
      |> Ash.read!(authorize?: false)

    socket
    |> assign(:documents, documents)
    |> assign(:owner_names, user_name_map())
    |> assign(:org_names, org_name_map())
    |> assign(:org_filter_options, org_options(socket))
  end

  # Superuser lihat semua; non-superuser hanya dokumen org aktif.
  defp base_scope(socket) do
    if su?(socket),
      do: Document,
      else: Ash.Query.filter(Document, organization_id == ^active_org(socket))
  end

  # Filter per org hanya untuk superuser (non-superuser sudah dikunci org aktif).
  defp maybe_filter_org(query, socket) do
    org_id = socket.assigns.organization_id

    if su?(socket) and org_id != "",
      do: Ash.Query.filter(query, organization_id == ^org_id),
      else: query
  end

  # Non-superuser: kunci organization_id ke org aktif + user_id ke dirinya.
  defp put_scope(params, socket) do
    if su?(socket) do
      params
    else
      params
      |> Map.put("organization_id", active_org(socket))
      |> Map.put("user_id", socket.assigns.current_user.id)
    end
  end

  # course_id/mime_type/description "" -> nil.
  defp normalize(params) do
    Enum.reduce(["course_id", "mime_type", "description"], params, fn key, acc ->
      if Map.get(acc, key) in ["", nil], do: Map.put(acc, key, nil), else: acc
    end)
  end

  # Superuser: semua user; non-superuser: hanya dirinya (pengunggah).
  defp user_options(socket) do
    users =
      if su?(socket),
        do: Ash.read!(User, authorize?: false),
        else: [socket.assigns.current_user]

    users
    |> Enum.sort_by(& &1.full_name)
    |> Enum.map(&{"#{&1.full_name} (#{&1.email})", &1.id})
  end

  # Superuser: semua org; non-superuser: hanya org aktif.
  defp org_options(socket) do
    Organization
    |> Ash.read!(authorize?: false)
    |> then(fn orgs ->
      if su?(socket), do: orgs, else: Enum.filter(orgs, &(&1.id == active_org(socket)))
    end)
    |> Enum.sort_by(& &1.name)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp user_name_map,
    do: User |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, to_string(&1.email)})

  defp org_name_map,
    do: Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})

  defp index_path(""), do: ~p"/documents"
  defp index_path(org_id), do: ~p"/documents?#{%{"organization_id" => org_id}}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:documents}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        Documents
        <:subtitle>All documents (document bank) across tenants.</:subtitle>
        <:actions>
          <.link patch={~p"/documents/new"}>
            <.button variant="primary">New document</.button>
          </.link>
        </:actions>
      </.header>

      <form
        :if={@permissions == :all}
        id="document-filter"
        phx-change="filter"
        class="mb-4 flex flex-wrap items-center gap-2"
      >
        <select name="organization_id" class="select select-bordered select-sm">
          <option value="">All organizations</option>
          <option
            :for={{label, id} <- @org_filter_options}
            value={id}
            selected={@organization_id == id}
          >
            {label}
          </option>
        </select>
        <.link :if={@organization_id != ""} patch={~p"/documents"} class="btn btn-sm btn-ghost">
          Reset
        </.link>
      </form>

      <.table id="documents" rows={@documents}>
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
        <:col :let={d} label="Created">{JosjobWeb.Format.datetime(d.created_at)}</:col>
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

      <div :if={@live_action == :new} id="document-modal" class="modal modal-open">
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">New document</h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:title]} type="text" label="Title" required />
            <.input field={@form[:url]} type="text" label="File URL" required />
            <.input field={@form[:mime_type]} type="text" label="Mime type (e.g. application/pdf)" />
            <.input field={@form[:description]} type="textarea" label="Description" rows="2" />
            <.input
              field={@form[:user_id]}
              type="select"
              label="Owner (uploader)"
              options={@user_options}
              prompt="— Select user —"
              required
            />
            <.input
              field={@form[:organization_id]}
              type="select"
              label="Organization (tenant)"
              options={@org_form_options}
              prompt="— Select organization —"
              required
            />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
              <.link patch={index_path(@organization_id)} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={index_path(@organization_id)} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
