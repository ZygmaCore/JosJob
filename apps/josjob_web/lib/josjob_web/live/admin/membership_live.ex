defmodule JosjobWeb.Admin.MembershipLive do
  @moduledoc """
  Menu admin Memberships versi LiveView — halaman per-org pertama yang live.
  `members:read` = lihat list (ter-scope org aktif); `members:manage` = kelola
  (modal New/Edit + delete; create non-superuser dipaksa ke org aktif).
  Gate route: hook LiveAuth `:assign_org` + `{:require, members:*}`.
  """
  use JosjobWeb, :live_view

  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Orgs.{Membership, Organization}

  @statuses [{"Active", "active"}, {"Invited", "invited"}, {"Suspended", "suspended"}]

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]

  defp can_manage?(socket),
    do: JosjobWeb.Perms.can?(socket.assigns[:permissions], "members:manage")

  defp in_scope?(socket, m), do: su?(socket) or m.organization_id == active_org(socket)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:status_options, @statuses)
     |> assign(:audit_labels, JosjobWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:q, q)
     |> load_memberships()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    if can_manage?(socket) do
      form =
        AshPhoenix.Form.for_create(Membership, :create,
          as: "membership",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket |> assign(:form, to_form(form)) |> assign_form_options()
    else
      forbid(socket)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    membership = Ash.get!(Membership, id, authorize?: false)

    if can_manage?(socket) and in_scope?(socket, membership) do
      form =
        AshPhoenix.Form.for_update(membership, :update,
          as: "membership",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket |> assign(:form, to_form(form)) |> assign_form_options()
    else
      forbid(socket)
    end
  end

  defp forbid(socket) do
    socket
    |> assign(:form, nil)
    |> put_flash(:error, "You don't have permission for that action.")
    |> push_patch(to: index_path(socket.assigns.q))
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: index_path(q))}
  end

  def handle_event("validate", %{"membership" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"membership" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    # Non-superuser: paksa membership ke org aktifnya (create maupun edit).
    params =
      if su?(socket),
        do: params,
        else: Map.put(params, "organization_id", active_org(socket))

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _m} ->
        {:noreply,
         socket
         |> put_flash(:info, "Membership #{verb}.")
         |> push_patch(to: index_path(socket.assigns.q))}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    membership = Ash.get!(Membership, id, authorize?: false)

    if can_manage?(socket) and in_scope?(socket, membership) do
      Ash.destroy!(membership, authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Membership deleted.")
       |> load_memberships()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  # Scope + filter identik dengan MembershipController lama.
  defp load_memberships(socket) do
    user_names = user_name_map()
    org_names = org_name_map()

    memberships =
      base_scope(socket)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.read!(authorize?: false)
      |> filter_memberships(socket.assigns.q, user_names, org_names)

    socket
    |> assign(:memberships, memberships)
    |> assign(:user_names, user_names)
    |> assign(:org_names, org_names)
  end

  defp base_scope(socket) do
    if su?(socket),
      do: Membership,
      else: Ash.Query.filter(Membership, organization_id == ^active_org(socket))
  end

  # Membership tak punya field teks sendiri -> cari di label user/org + status.
  defp filter_memberships(list, "", _user_names, _org_names), do: list

  defp filter_memberships(list, q, user_names, org_names) do
    down = String.downcase(q)

    Enum.filter(list, fn m ->
      [user_names[m.user_id], org_names[m.organization_id], to_string(m.status)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.downcase()
      |> String.contains?(down)
    end)
  end

  defp assign_form_options(socket) do
    socket
    |> assign(:user_options, user_options())
    |> assign(:org_options, org_options(socket))
  end

  defp user_options do
    User
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.full_name)
    |> Enum.map(&{"#{&1.full_name} (#{&1.email})", &1.id})
  end

  # Superuser: semua org; non-superuser: hanya org aktifnya.
  defp org_options(socket) do
    orgs =
      if su?(socket) do
        Organization |> Ash.read!(authorize?: false)
      else
        Organization
        |> Ash.Query.filter(id == ^active_org(socket))
        |> Ash.read!(authorize?: false)
      end

    orgs |> Enum.sort_by(& &1.name) |> Enum.map(&{&1.name, &1.id})
  end

  defp user_name_map do
    User |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, "#{&1.full_name} (#{&1.email})"})
  end

  defp org_name_map do
    Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end

  defp index_path(""), do: ~p"/memberships"
  defp index_path(q), do: ~p"/memberships?#{%{"q" => q}}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:memberships}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        Memberships
        <:subtitle>User membership in organizations.</:subtitle>
        <:actions>
          <.link
            :if={JosjobWeb.Perms.can?(@permissions, "members:manage")}
            patch={~p"/memberships/new"}
          >
            <.button variant="primary">New membership</.button>
          </.link>
        </:actions>
      </.header>

      <form id="membership-filter" phx-change="filter" class="mb-4 flex flex-wrap items-center gap-2">
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="Search user / organization / status…"
          phx-debounce="300"
          class="input input-bordered input-sm w-full max-w-xs"
        />
        <.link :if={@q != ""} patch={~p"/memberships"} class="btn btn-sm btn-ghost">Reset</.link>
      </form>

      <.table id="memberships" rows={@memberships}>
        <:col :let={m} label="User">{@user_names[m.user_id] || "-"}</:col>
        <:col :let={m} label="Organization">{@org_names[m.organization_id] || "-"}</:col>
        <:col :let={m} label="Status">
          <span class="badge badge-neutral">{m.status}</span>
        </:col>
        <:col :let={m} label="Created">{JosjobWeb.Format.datetime(m.created_at)}</:col>
        <:col :let={m} label="Updated">{JosjobWeb.Format.datetime(m.updated_at)}</:col>
        <:col :let={m} label="Created by">{@audit_labels[m.created_by] || "-"}</:col>
        <:col :let={m} label="Updated by">{@audit_labels[m.updated_by] || "-"}</:col>
        <:action :let={m}>
          <.link
            :if={JosjobWeb.Perms.can?(@permissions, "members:manage")}
            patch={~p"/memberships/#{m.id}/edit"}
            class="btn btn-ghost btn-xs"
          >
            Edit
          </.link>
        </:action>
        <:action :let={m}>
          <.link
            :if={JosjobWeb.Perms.can?(@permissions, "members:manage")}
            phx-click="delete"
            phx-value-id={m.id}
            data-confirm="Delete this membership?"
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div
        :if={@live_action in [:new, :edit] and @form != nil}
        id="membership-modal"
        class="modal modal-open"
      >
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New membership", else: "Edit membership"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input
              field={@form[:user_id]}
              type="select"
              label="User"
              options={@user_options}
              prompt="— Select user —"
              required
            />
            <.input
              field={@form[:organization_id]}
              type="select"
              label="Organization"
              options={@org_options}
              prompt="— Select organization —"
              required
            />
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={@status_options}
              required
            />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
              <.link patch={index_path(@q)} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={index_path(@q)} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
