defmodule StellarWeb.Admin.OrganizationLive do
  @moduledoc """
  Menu admin Organizations (tenant) versi LiveView. Gate `organizations:read`;
  superuser lihat semua + create/delete; non-superuser hanya org aktifnya dan
  boleh edit bila punya `organizations:manage`. Search + filter industri live
  (state URL).
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Industry, Organization}

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]

  defp can_manage?(socket),
    do: StellarWeb.Perms.can?(socket.assigns[:permissions], "organizations:manage")

  # Boleh edit: punya organizations:manage dan (superuser atau org-nya sendiri).
  defp editable?(socket, org),
    do: can_manage?(socket) and (su?(socket) or org.id == active_org(socket))

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :audit_labels, StellarWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()
    industry_id = params |> Map.get("industry_id", "") |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:q, q)
     |> assign(:industry_id, industry_id)
     |> load_organizations()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  # Buat organisasi (tenant) baru = aksi platform (superuser).
  defp apply_action(socket, :new, _params) do
    if su?(socket) do
      form =
        AshPhoenix.Form.for_create(Organization, :create,
          as: "organization",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket |> assign(:form, to_form(form)) |> assign_modal_options()
    else
      forbid(socket)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    org = Ash.get!(Organization, id, authorize?: false)

    if editable?(socket, org) do
      form =
        AshPhoenix.Form.for_update(org, :update,
          as: "organization",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket |> assign(:form, to_form(form)) |> assign_modal_options()
    else
      forbid(socket)
    end
  end

  defp assign_modal_options(socket) do
    socket
    |> assign(:user_options, user_options())
    |> assign(:industry_tree_options, industry_tree_options())
  end

  defp forbid(socket) do
    socket
    |> assign(:form, nil)
    |> put_flash(:error, "You don't have permission for that action.")
    |> push_patch(to: index_path(socket.assigns.q, socket.assigns.industry_id))
  end

  @impl true
  def handle_event("filter", %{"q" => q, "industry_id" => industry_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(q, industry_id))}
  end

  def handle_event("validate", %{"organization" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"organization" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: normalize(params)) do
      {:ok, org} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization #{org.name} #{verb}.")
         |> push_patch(to: index_path(socket.assigns.q, socket.assigns.industry_id))}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  # Hapus tenant = aksi platform (superuser).
  def handle_event("delete", %{"id" => id}, socket) do
    if su?(socket) do
      org = Ash.get!(Organization, id, authorize?: false)

      socket =
        case Ash.destroy(org, authorize?: false) do
          :ok ->
            put_flash(socket, :info, "Organization #{org.name} deleted.")

          {:error, _} ->
            put_flash(socket, :error, "Failed to delete (may still be used by a membership).")
        end

      {:noreply, load_organizations(socket)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  # Scope + filter identik dengan OrganizationController lama.
  defp load_organizations(socket) do
    orgs =
      base_scope(socket)
      |> Ash.Query.sort(created_at: :desc)
      |> search(socket.assigns.q)
      |> filter_industry(socket.assigns.industry_id)
      |> Ash.read!(authorize?: false)

    socket
    |> assign(:organizations, orgs)
    |> assign(:owner_names, owner_name_map())
    |> assign(:industry_names, industry_name_map())
    |> assign(:industry_options, industry_tree_options())
  end

  defp base_scope(socket) do
    if su?(socket),
      do: Organization,
      else: Ash.Query.filter(Organization, id == ^active_org(socket))
  end

  defp search(query, ""), do: query

  defp search(query, q) do
    like = "%" <> q <> "%"
    Ash.Query.filter(query, fragment("? ILIKE ?", name, ^like))
  end

  defp filter_industry(query, ""), do: query
  defp filter_industry(query, id), do: Ash.Query.filter(query, industry_id == ^id)

  defp user_options do
    User
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.full_name)
    |> Enum.map(&{"#{&1.full_name} (#{&1.email})", &1.id})
  end

  # Opsi industri berbentuk POHON (dropdown modal DAN filter list): depth-first mengikuti
  # parent_id, anak menjorok ("└ " + indentasi nbsp per level). Set `seen`
  # mencegah loop bila data membentuk siklus induk-anak.
  defp industry_tree_options do
    by_parent =
      Industry
      |> Ash.read!(authorize?: false)
      |> Enum.group_by(& &1.parent_id)

    walk_industry_tree(by_parent, nil, 0, MapSet.new())
  end

  defp walk_industry_tree(by_parent, parent_id, depth, seen) do
    by_parent
    |> Map.get(parent_id, [])
    |> Enum.sort_by(& &1.name)
    |> Enum.flat_map(fn i ->
      if MapSet.member?(seen, i.id) do
        []
      else
        # indentasi memakai non-breaking space (U+00A0) — spasi biasa di-collapse browser
        indent = String.duplicate("  ", depth)
        marker = if depth > 0, do: "└ ", else: ""

        [
          {indent <> marker <> i.name, i.id}
          | walk_industry_tree(by_parent, i.id, depth + 1, MapSet.put(seen, i.id))
        ]
      end
    end)
  end

  defp owner_name_map do
    User |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, "#{&1.full_name} (#{&1.email})"})
  end

  defp industry_name_map do
    Industry |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end

  defp normalize(params) do
    if Map.get(params, "industry_id") in ["", nil],
      do: Map.put(params, "industry_id", nil),
      else: params
  end

  defp index_path(q, industry_id) do
    params =
      %{"q" => q, "industry_id" => industry_id}
      |> Enum.reject(fn {_k, v} -> v in ["", nil] end)
      |> Map.new()

    if params == %{}, do: ~p"/organizations", else: ~p"/organizations?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:organizations}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        Organizations
        <:subtitle>Tenant / organizations.</:subtitle>
        <:actions>
          <.link :if={@permissions == :all} patch={~p"/organizations/new"}>
            <.button variant="primary">New organization</.button>
          </.link>
        </:actions>
      </.header>

      <form
        id="organization-filter"
        phx-change="filter"
        class="mb-4 flex flex-wrap items-center gap-2"
      >
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="Search organization name…"
          phx-debounce="300"
          class="input input-bordered input-sm w-full max-w-xs"
        />
        <select name="industry_id" class="select select-bordered select-sm">
          <option value="">All industries</option>
          <option :for={{label, id} <- @industry_options} value={id} selected={@industry_id == id}>
            {label}
          </option>
        </select>
        <.link
          :if={@q != "" or @industry_id != ""}
          patch={~p"/organizations"}
          class="btn btn-sm btn-ghost"
        >
          Reset
        </.link>
      </form>

      <.table id="organizations" rows={@organizations}>
        <:col :let={o} label="Name">{o.name}</:col>
        <:col :let={o} label="Owner">{@owner_names[o.user_id] || "-"}</:col>
        <:col :let={o} label="Industry">{@industry_names[o.industry_id] || "-"}</:col>
        <:col :let={o} label="Phone">{o.phone}</:col>
        <:col :let={o} label="Created">{StellarWeb.Format.datetime(o.created_at)}</:col>
        <:col :let={o} label="Updated">{StellarWeb.Format.datetime(o.updated_at)}</:col>
        <:col :let={o} label="Created by">{@audit_labels[o.created_by] || "-"}</:col>
        <:col :let={o} label="Updated by">{@audit_labels[o.updated_by] || "-"}</:col>
        <:action :let={o}>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, "organizations:manage")}
            patch={~p"/organizations/#{o.id}/edit"}
            class="btn btn-ghost btn-xs"
          >
            Edit
          </.link>
        </:action>
        <:action :let={o}>
          <.link
            :if={@permissions == :all}
            phx-click="delete"
            phx-value-id={o.id}
            data-confirm={"Delete organization #{o.name}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div
        :if={@live_action in [:new, :edit] and @form != nil}
        id="organization-modal"
        class="modal modal-open"
      >
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New organization", else: "Edit organization"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:name]} type="text" label="Organization name" required />
            <.input
              field={@form[:user_id]}
              type="select"
              label="Owner"
              options={@user_options}
              prompt="— Select user —"
              required
            />
            <.input
              field={@form[:industry_id]}
              type="select"
              label="Industry"
              options={@industry_tree_options}
              prompt="— Select industry —"
            />
            <.input field={@form[:phone]} type="text" label="Phone" />
            <.input field={@form[:address]} type="text" label="Address" />
            <.input field={@form[:additional_info]} type="textarea" label="Additional info" rows="2" />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
              <.link patch={index_path(@q, @industry_id)} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={index_path(@q, @industry_id)} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
