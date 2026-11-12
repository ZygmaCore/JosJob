defmodule JosjobWeb.Admin.PermissionLive do
  @moduledoc """
  Menu admin Permissions versi LiveView (pola pilot Skills): list + search live
  (key/category/description) + pagination (state di URL) + form modal + delete.
  """
  use JosjobWeb, :live_view

  require Ash.Query

  alias Josjob.Rbac.Permission

  @per_page_options [10, 20, 40]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:per_page_options, @per_page_options)
     |> assign(:audit_labels, JosjobWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:q, q)
     |> assign(:per_page, parse_per_page(params))
     |> assign(:page_param, parse_page(params))
     |> load_permissions()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    form =
      AshPhoenix.Form.for_create(Permission, :create,
        as: "permission",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    permission = Ash.get!(Permission, id, authorize?: false)

    form =
      AshPhoenix.Form.for_update(permission, :update,
        as: "permission",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  @impl true
  def handle_event("filter", %{"q" => q, "per_page" => per_page}, socket) do
    # Ganti pencarian/per_page selalu kembali ke halaman 1.
    {:noreply, push_patch(socket, to: index_path(q, per_page, 1))}
  end

  def handle_event("validate", %{"permission" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"permission" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, permission} ->
        {:noreply,
         socket
         |> put_flash(:info, "Permission #{permission.key} #{verb}.")
         |> push_patch(
           to: index_path(socket.assigns.q, socket.assigns.per_page, socket.assigns.page)
         )}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    permission = Ash.get!(Permission, id, authorize?: false)

    socket =
      case Ash.destroy(permission, authorize?: false) do
        :ok ->
          put_flash(socket, :info, "Permission #{permission.key} deleted.")

        {:error, _} ->
          put_flash(socket, :error, "Failed to delete (may still be used by a role).")
      end

    {:noreply, load_permissions(socket)}
  end

  # Query + pagination identik dengan PermissionController lama.
  defp load_permissions(socket) do
    %{q: q, per_page: per_page, page_param: page_param} = socket.assigns

    base = search(Permission, q)
    total = Ash.count!(base, authorize?: false)
    total_pages = max(div(total + per_page - 1, per_page), 1)
    page = min(page_param, total_pages)

    permissions =
      base
      |> Ash.Query.sort(key: :asc)
      |> Ash.Query.limit(per_page)
      |> Ash.Query.offset((page - 1) * per_page)
      |> Ash.read!(authorize?: false)

    socket
    |> assign(:permissions_page, permissions)
    |> assign(:total, total)
    |> assign(:total_pages, total_pages)
    |> assign(:page, page)
  end

  # Cari (case-insensitive) di key / kategori / deskripsi.
  defp search(query, ""), do: query

  defp search(query, q) do
    like = "%" <> q <> "%"

    Ash.Query.filter(
      query,
      fragment("? ILIKE ?", key, ^like) or
        fragment("? ILIKE ?", category, ^like) or
        fragment("? ILIKE ?", description, ^like)
    )
  end

  defp parse_per_page(params) do
    case params |> Map.get("per_page") |> to_string() |> Integer.parse() do
      {n, _} when n in @per_page_options -> n
      _ -> 10
    end
  end

  defp parse_page(params) do
    case params |> Map.get("page") |> to_string() |> Integer.parse() do
      {n, _} when n >= 1 -> n
      _ -> 1
    end
  end

  # Path index; nilai default (q kosong, per_page 10, page 1) tidak ditulis ke URL.
  defp index_path(q, per_page, page) do
    per_page = to_string(per_page)
    page = to_string(page)

    params =
      %{"q" => q, "per_page" => per_page, "page" => page}
      |> Enum.reject(fn
        {"q", v} -> v in ["", nil]
        {"per_page", v} -> v == "10"
        {"page", v} -> v == "1"
      end)
      |> Map.new()

    if params == %{}, do: ~p"/permissions", else: ~p"/permissions?#{params}"
  end

  defp action_path(:new), do: ~p"/permissions/new"
  defp action_path({:edit, id}), do: ~p"/permissions/#{id}/edit"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} active={:permissions} current_user={@current_user}>
      <.header>
        Permissions
        <:subtitle>Permission catalog (resource:action).</:subtitle>
        <:actions>
          <.link patch={action_path(:new)}>
            <.button variant="primary">New permission</.button>
          </.link>
        </:actions>
      </.header>

      <form id="permission-filter" phx-change="filter" class="mb-4 flex flex-wrap items-center gap-2">
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="Search key / category / description…"
          phx-debounce="300"
          class="input input-bordered input-sm w-full max-w-xs"
        />
        <select name="per_page" class="select select-bordered select-sm">
          <option :for={n <- @per_page_options} value={n} selected={@per_page == n}>
            {n} / page
          </option>
        </select>
        <.link :if={@q != ""} patch={~p"/permissions"} class="btn btn-sm btn-ghost">Reset</.link>
      </form>

      <.table id="permissions" rows={@permissions_page}>
        <:col :let={p} label="Key">{p.key}</:col>
        <:col :let={p} label="Category">{p.category}</:col>
        <:col :let={p} label="Description">{p.description}</:col>
        <:col :let={p} label="Created">{JosjobWeb.Format.datetime(p.created_at)}</:col>
        <:col :let={p} label="Updated">{JosjobWeb.Format.datetime(p.updated_at)}</:col>
        <:col :let={p} label="Created by">{@audit_labels[p.created_by] || "-"}</:col>
        <:col :let={p} label="Updated by">{@audit_labels[p.updated_by] || "-"}</:col>
        <:action :let={p}>
          <.link patch={action_path({:edit, p.id})} class="btn btn-ghost btn-xs">Edit</.link>
        </:action>
        <:action :let={p}>
          <.link
            phx-click="delete"
            phx-value-id={p.id}
            data-confirm={"Delete permission #{p.key}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-2">
        <span class="text-sm opacity-70">
          Total {@total} · Page {@page} of {@total_pages}
        </span>
        <div class="join">
          <.link
            :if={@page > 1}
            patch={index_path(@q, @per_page, @page - 1)}
            class="join-item btn btn-sm"
          >
            « Previous
          </.link>
          <span :if={@page <= 1} class="join-item btn btn-sm btn-disabled">« Previous</span>
          <.link
            :if={@page < @total_pages}
            patch={index_path(@q, @per_page, @page + 1)}
            class="join-item btn btn-sm"
          >
            Next »
          </.link>
          <span :if={@page >= @total_pages} class="join-item btn btn-sm btn-disabled">
            Next »
          </span>
        </div>
      </div>

      <div :if={@live_action in [:new, :edit]} id="permission-modal" class="modal modal-open">
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New permission", else: "Edit permission"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:key]} type="text" label="Key (resource:action)" required />
            <.input field={@form[:category]} type="text" label="Category" />
            <.input field={@form[:description]} type="text" label="Description" />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
              <.link patch={index_path(@q, @per_page, @page)} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={index_path(@q, @per_page, @page)} class="modal-backdrop" aria-label="Close">
        </.link>
      </div>
    </Layouts.admin>
    """
  end
end
