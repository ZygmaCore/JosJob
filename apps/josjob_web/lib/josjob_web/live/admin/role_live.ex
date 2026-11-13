defmodule JosjobWeb.Admin.RoleLive do
  @moduledoc """
  Menu admin Roles versi LiveView (pola pilot Skills): list + form modal
  (atribut + organisasi + checkbox permissions → sync `role_permissions`).
  `is_system` sengaja tidak tampil di UI; role baru memakai default atribut.
  """
  use JosjobWeb, :live_view

  require Ash.Query

  alias Josjob.Orgs.Organization
  alias Josjob.Rbac.{Permission, Role, RolePermission}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       :permissions_list,
       Permission |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.key)
     )
     |> assign(:org_options, org_options())
     |> assign(:org_names, org_name_map())
     |> assign(:audit_labels, JosjobWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> load_roles()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params),
    do: socket |> assign(:form, nil) |> assign(:checked, [])

  defp apply_action(socket, :new, _params) do
    form =
      AshPhoenix.Form.for_create(Role, :create,
        as: "role",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    socket |> assign(:form, to_form(form)) |> assign(:checked, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    role = Ash.get!(Role, id, authorize?: false)

    form =
      AshPhoenix.Form.for_update(role, :update,
        as: "role",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    socket |> assign(:form, to_form(form)) |> assign(:checked, role_permission_ids(id))
  end

  @impl true
  def handle_event("validate", %{"role" => params}, socket) do
    {ids, attrs} = pop_permission_ids(params)

    {:noreply,
     socket
     |> assign(:form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, attrs)))
     |> assign(:checked, ids)}
  end

  def handle_event("save", %{"role" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"
    {ids, attrs} = pop_permission_ids(params)

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: normalize(attrs)) do
      {:ok, role} ->
        sync_permissions(role.id, ids)

        {:noreply,
         socket
         |> put_flash(:info, "Role #{role.name} #{verb}.")
         |> push_patch(to: ~p"/roles")}

      {:error, form} ->
        {:noreply, socket |> assign(:form, to_form(form)) |> assign(:checked, ids)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    role = Ash.get!(Role, id, authorize?: false)
    # role_permissions ikut terhapus (FK CASCADE).
    Ash.destroy!(role, authorize?: false)

    {:noreply,
     socket
     |> put_flash(:info, "Role #{role.name} deleted.")
     |> load_roles()}
  end

  defp load_roles(socket) do
    roles = Role |> Ash.Query.sort(created_at: :desc) |> Ash.read!(authorize?: false)

    socket
    |> assign(:roles, roles)
    |> assign(:counts, permission_counts())
  end

  # Checkbox permissions dikirim di params["permission_ids"]; pisahkan dari attr role.
  defp pop_permission_ids(params) do
    ids =
      params |> Map.get("permission_ids", []) |> List.wrap() |> Enum.reject(&(&1 in ["", nil]))

    {ids, Map.delete(params, "permission_ids")}
  end

  # organization_id "" (opsi Global) -> nil.
  defp normalize(params) do
    if Map.get(params, "organization_id") in ["", nil],
      do: Map.put(params, "organization_id", nil),
      else: params
  end

  # Set role_permissions agar persis = ids (hapus semua, buat ulang).
  defp sync_permissions(role_id, perm_ids) do
    RolePermission
    |> Ash.Query.filter(role_id == ^role_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    Enum.each(perm_ids, fn pid ->
      RolePermission
      |> Ash.Changeset.for_create(:create, %{role_id: role_id, permission_id: pid})
      |> Ash.create!(authorize?: false)
    end)
  end

  defp role_permission_ids(role_id) do
    RolePermission
    |> Ash.Query.filter(role_id == ^role_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.permission_id)
  end

  defp permission_counts do
    RolePermission |> Ash.read!(authorize?: false) |> Enum.frequencies_by(& &1.role_id)
  end

  defp org_options do
    Organization
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.name)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp org_name_map do
    Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} active={:roles} current_user={@current_user}>
      <.header>
        Roles
        <:subtitle>Roles & their permissions (global or per organization).</:subtitle>
        <:actions>
          <.link patch={~p"/roles/new"}>
            <.button variant="primary">New role</.button>
          </.link>
        </:actions>
      </.header>

      <.table id="roles" rows={@roles}>
        <:col :let={r} label="Name">{r.name}</:col>
        <:col :let={r} label="Display name">{r.display_name}</:col>
        <:col :let={r} label="Key">{r.key}</:col>
        <:col :let={r} label="Organization">{@org_names[r.organization_id] || "Global"}</:col>
        <:col :let={r} label="Permissions">{Map.get(@counts, r.id, 0)}</:col>
        <:col :let={r} label="Created">{JosjobWeb.Format.datetime(r.created_at)}</:col>
        <:col :let={r} label="Updated">{JosjobWeb.Format.datetime(r.updated_at)}</:col>
        <:col :let={r} label="Created by">{@audit_labels[r.created_by] || "-"}</:col>
        <:col :let={r} label="Updated by">{@audit_labels[r.updated_by] || "-"}</:col>
        <:action :let={r}>
          <.link patch={~p"/roles/#{r.id}/edit"} class="btn btn-ghost btn-xs">Edit</.link>
        </:action>
        <:action :let={r}>
          <.link
            phx-click="delete"
            phx-value-id={r.id}
            data-confirm={"Delete role #{r.name}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@live_action in [:new, :edit]} id="role-modal" class="modal modal-open">
        <div class="modal-box max-w-2xl">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New role", else: "Edit role"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:key]} type="text" label="Key (e.g. coordinator)" required />
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input field={@form[:display_name]} type="text" label="Display name" />
            <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

            <.input
              field={@form[:organization_id]}
              type="select"
              label="Organization"
              options={@org_options}
              prompt="Global (all orgs)"
            />

            <fieldset class="fieldset">
              <legend class="fieldset-legend">Permissions</legend>
              <div class="grid max-h-64 grid-cols-1 gap-2 overflow-y-auto sm:grid-cols-2">
                <label
                  :for={p <- @permissions_list}
                  class="label cursor-pointer justify-start gap-2"
                >
                  <input
                    type="checkbox"
                    name="role[permission_ids][]"
                    value={p.id}
                    checked={p.id in @checked}
                    class="checkbox checkbox-sm"
                  />
                  <span class="font-mono text-sm">{p.key}</span>
                </label>
              </div>
            </fieldset>

            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
              <.link patch={~p"/roles"} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={~p"/roles"} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
