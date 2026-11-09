defmodule StellarWeb.Admin.MembershipRoleLive do
  @moduledoc """
  Menu admin Membership Roles versi LiveView (tautan role ↔ membership).

  - Lihat daftar: `members:read`. Kelola (assign/hapus): `members:manage`.
  - **Per-org**: non-superuser hanya membership & role di org aktifnya.
  - **Anti-eskalasi**: non-superuser hanya boleh menautkan role yang izinnya
    ⊆ izin efektif dirinya. Superuser melewati semua batasan.
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias Stellar.Orgs.Membership
  alias Stellar.Rbac.{MembershipRole, Permission, Role, RolePermission}

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]

  defp can_manage?(socket),
    do: StellarWeb.Perms.can?(socket.assigns[:permissions], "members:manage")

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :audit_labels, StellarWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> load_membership_roles()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    if can_manage?(socket) do
      form =
        AshPhoenix.Form.for_create(MembershipRole, :create,
          as: "membership_role",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket
      |> assign(:form, to_form(form))
      |> assign(:membership_options, membership_options(socket))
      |> assign(:role_options, role_options(socket))
    else
      socket
      |> assign(:form, nil)
      |> put_flash(:error, "You don't have permission for that action.")
      |> push_patch(to: ~p"/membership-roles")
    end
  end

  @impl true
  def handle_event("validate", %{"membership_role" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"membership_role" => params}, socket) do
    cond do
      not can_manage?(socket) ->
        {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}

      not membership_in_scope?(socket, params["membership_id"]) ->
        {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}

      not assignable_role_id?(socket, params["role_id"]) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That role cannot be linked by you (outside your org / exceeds your permissions)."
         )}

      true ->
        case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Role linked to membership.")
             |> push_patch(to: ~p"/membership-roles")}

          {:error, form} ->
            {:noreply, assign(socket, :form, to_form(form))}
        end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    mr = MembershipRole |> Ash.get!(id, authorize?: false)

    if can_manage?(socket) and membership_in_scope?(socket, mr.membership_id) do
      Ash.destroy!(mr, authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Role link deleted.")
       |> load_membership_roles()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  # Index: superuser semua; non-superuser hanya tautan pada membership org aktif.
  defp load_membership_roles(socket) do
    scope =
      if su?(socket),
        do: MembershipRole,
        else: Ash.Query.filter(MembershipRole, membership.organization_id == ^active_org(socket))

    socket
    |> assign(:membership_roles, Ash.read!(scope, authorize?: false))
    |> assign(:membership_labels, membership_label_map())
    |> assign(:role_names, role_name_map())
  end

  # --- guards (identik dengan controller lama) ---

  defp membership_in_scope?(socket, nil), do: su?(socket)

  defp membership_in_scope?(socket, membership_id) do
    su?(socket) or
      case Ash.get(Membership, membership_id, authorize?: false) do
        {:ok, m} -> m.organization_id == active_org(socket)
        _ -> false
      end
  end

  defp assignable_role_id?(socket, nil), do: su?(socket)

  defp assignable_role_id?(socket, role_id) do
    su?(socket) or
      case Ash.get(Role, role_id, authorize?: false) do
        {:ok, role} -> assignable_role?(socket, role)
        _ -> false
      end
  end

  defp assignable_role?(socket, role) do
    su?(socket) or
      (role.organization_id == active_org(socket) and role_perms_subset?(socket, role.id))
  end

  defp role_perms_subset?(socket, role_id) do
    case socket.assigns[:permissions] do
      :all -> true
      %MapSet{} = mine -> MapSet.subset?(role_permission_keys(role_id), mine)
      _ -> false
    end
  end

  defp role_permission_keys(role_id) do
    perm_ids =
      RolePermission
      |> Ash.Query.filter(role_id == ^role_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.permission_id)

    if perm_ids == [] do
      MapSet.new()
    else
      Permission
      |> Ash.Query.filter(id in ^perm_ids)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.key)
      |> MapSet.new()
    end
  end

  # --- form options (ter-scope) ---

  defp membership_options(socket) do
    scope =
      if su?(socket),
        do: Membership,
        else: Ash.Query.filter(Membership, organization_id == ^active_org(socket))

    scope
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:user, :organization], authorize?: false)
    |> Enum.map(&{label(&1), &1.id})
  end

  defp role_options(socket) do
    roles =
      if su?(socket) do
        Role |> Ash.read!(authorize?: false)
      else
        Role
        |> Ash.Query.filter(organization_id == ^active_org(socket))
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&assignable_role?(socket, &1))
      end

    roles |> Enum.sort_by(& &1.name) |> Enum.map(&{&1.name, &1.id})
  end

  defp label(m), do: "#{to_string(m.user.email)} @ #{m.organization.name}"

  defp membership_label_map do
    Membership
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:user, :organization], authorize?: false)
    |> Map.new(&{&1.id, label(&1)})
  end

  defp role_name_map do
    Role |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:membership_roles}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        Membership Roles
        <:subtitle>Role links on memberships.</:subtitle>
        <:actions>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, "members:manage")}
            patch={~p"/membership-roles/new"}
          >
            <.button variant="primary">Assign role</.button>
          </.link>
        </:actions>
      </.header>

      <.table id="membership-roles" rows={@membership_roles}>
        <:col :let={mr} label="Membership">{@membership_labels[mr.membership_id] || "-"}</:col>
        <:col :let={mr} label="Role">{@role_names[mr.role_id] || "-"}</:col>
        <:col :let={mr} label="Created by">{@audit_labels[mr.created_by] || "-"}</:col>
        <:col :let={mr} label="Updated by">{@audit_labels[mr.updated_by] || "-"}</:col>
        <:action :let={mr}>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, "members:manage")}
            phx-click="delete"
            phx-value-id={mr.id}
            data-confirm="Delete this role link?"
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div
        :if={@live_action == :new and @form != nil}
        id="membership-role-modal"
        class="modal modal-open"
      >
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">Assign role to membership</h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input
              field={@form[:membership_id]}
              type="select"
              label="Membership"
              options={@membership_options}
              prompt="— Select membership —"
              required
            />
            <.input
              field={@form[:role_id]}
              type="select"
              label="Role"
              options={@role_options}
              prompt="— Select role —"
              required
            />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Saving...">Assign</.button>
              <.link patch={~p"/membership-roles"} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={~p"/membership-roles"} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
