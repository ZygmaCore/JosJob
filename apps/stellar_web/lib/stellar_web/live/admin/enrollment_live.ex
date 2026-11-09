defmodule StellarWeb.Admin.EnrollmentLive do
  @moduledoc """
  Menu admin Enrollments (mandiri) versi LiveView. Gate granular:
  `enrollments:read` (lihat) · `create` (modal daftar) · `update` (ubah status)
  · `delete` (keluarkan); `enrollments:manage` = superset. Superuser semua;
  non-superuser hanya enrollment pada kelas org aktif. Filter kelas + cari nama
  siswa + pagination — semuanya live dengan state di URL.
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias StellarLrn.Learning.{Class, Enrollment}
  alias Stellar.Orgs.Membership
  alias Stellar.Accounts.User

  @per_page_options [10, 20, 40]

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]
  defp p(socket, list), do: StellarWeb.Perms.can?(socket.assigns[:permissions], list)
  defp can_create?(socket), do: p(socket, ["enrollments:create", "enrollments:manage"])
  defp can_update?(socket), do: p(socket, ["enrollments:update", "enrollments:manage"])
  defp can_delete?(socket), do: p(socket, ["enrollments:delete", "enrollments:manage"])

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :per_page_options, @per_page_options)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:class_id, params |> Map.get("class_id", "") |> to_string() |> String.trim())
     |> assign(:q, params |> Map.get("q", "") |> to_string() |> String.trim())
     |> assign(:per_page, parse_per_page(params))
     |> assign(:page_param, parse_page(params))
     |> load_enrollments()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    if can_create?(socket) do
      form =
        AshPhoenix.Form.for_create(Enrollment, :create, as: "enrollment", authorize?: false)

      socket
      |> assign(:form, to_form(form))
      |> assign(:student_options, student_options(socket))
    else
      socket
      |> assign(:form, nil)
      |> put_flash(:error, "You don't have permission for that action.")
      |> push_patch(to: index_path(socket))
    end
  end

  @impl true
  def handle_event("filter", %{"class_id" => class_id, "q" => q, "per_page" => per_page}, socket) do
    # Ganti filter selalu kembali ke halaman 1.
    {:noreply, push_patch(socket, to: build_path(class_id, q, per_page, 1))}
  end

  def handle_event("validate", %{"enrollment" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"enrollment" => params}, socket) do
    class_id = params["class_id"]

    cond do
      not can_create?(socket) ->
        {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}

      not class_in_scope?(socket, class_id) ->
        {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}

      true ->
        result =
          Enrollment
          |> Ash.Changeset.for_create(:create, %{
            class_id: class_id,
            student_id: params["student_id"]
          })
          |> Ash.create(authorize?: false)

        case result do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Student enrolled.")
             |> push_patch(to: index_path(socket))}

          {:error, _} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Failed to enroll (class full or student already enrolled)."
             )}
        end
    end
  end

  def handle_event("set_status", %{"id" => id, "status" => status}, socket) do
    enr = Ash.get!(Enrollment, id, authorize?: false, load: [:class])

    if can_update?(socket) and enrollment_in_scope?(socket, enr) do
      enr
      |> Ash.Changeset.for_update(:set_status, %{status: status})
      |> Ash.update!(authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Enrollment status updated.")
       |> load_enrollments()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    enr = Ash.get!(Enrollment, id, authorize?: false, load: [:class])

    if can_delete?(socket) and enrollment_in_scope?(socket, enr) do
      Ash.destroy!(enr, authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Enrollment deleted.")
       |> load_enrollments()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  # Query + pagination identik dengan EnrollmentController lama.
  defp load_enrollments(socket) do
    %{class_id: class_id, q: q, per_page: per_page, page_param: page_param} = socket.assigns

    base =
      base_scope(socket)
      |> filter_class(class_id)
      |> filter_student(q)

    total = Ash.count!(base, authorize?: false)
    total_pages = max(div(total + per_page - 1, per_page), 1)
    page = min(page_param, total_pages)

    enrollments =
      base
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load([:student, class: [:course]])
      |> Ash.Query.limit(per_page)
      |> Ash.Query.offset((page - 1) * per_page)
      |> Ash.read!(authorize?: false)

    socket
    |> assign(:enrollments, enrollments)
    |> assign(:class_options, class_options(socket))
    |> assign(:total, total)
    |> assign(:total_pages, total_pages)
    |> assign(:page, page)
  end

  # Superuser semua; non-superuser hanya enrollment di kelas org aktif.
  defp base_scope(socket) do
    if su?(socket),
      do: Enrollment,
      else: Ash.Query.filter(Enrollment, class.organization_id == ^active_org(socket))
  end

  defp class_in_scope?(socket, nil), do: su?(socket)

  defp class_in_scope?(socket, class_id) do
    su?(socket) or
      case Ash.get(Class, class_id, authorize?: false) do
        {:ok, c} -> c.organization_id == active_org(socket)
        _ -> false
      end
  end

  defp enrollment_in_scope?(socket, %Enrollment{class: %Class{} = c}),
    do: su?(socket) or c.organization_id == active_org(socket)

  defp enrollment_in_scope?(socket, _), do: su?(socket)

  defp filter_class(query, ""), do: query
  defp filter_class(query, class_id), do: Ash.Query.filter(query, class_id == ^class_id)

  defp filter_student(query, ""), do: query

  defp filter_student(query, q) do
    like = "%" <> q <> "%"

    user_ids =
      User
      |> Ash.Query.filter(fragment("? ILIKE ?", full_name, ^like))
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    Ash.Query.filter(query, student_id in ^user_ids)
  end

  defp class_options(socket) do
    scope =
      if su?(socket),
        do: Class,
        else: Ash.Query.filter(Class, organization_id == ^active_org(socket))

    scope
    |> Ash.Query.load([:course])
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{class_label(&1), &1.id})
  end

  defp class_label(c), do: "#{c.course && c.course.title} — #{c.title || "class"}"

  defp student_options(socket) do
    users =
      if su?(socket) do
        Ash.read!(User, authorize?: false)
      else
        member_ids =
          Membership
          |> Ash.Query.filter(organization_id == ^active_org(socket) and status == :active)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.user_id)

        if member_ids == [],
          do: [],
          else: User |> Ash.Query.filter(id in ^member_ids) |> Ash.read!(authorize?: false)
      end

    users
    |> Enum.sort_by(& &1.full_name)
    |> Enum.map(&{"#{&1.full_name} (#{&1.email})", &1.id})
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

  defp index_path(socket) do
    build_path(
      socket.assigns.class_id,
      socket.assigns.q,
      socket.assigns.per_page,
      socket.assigns.page
    )
  end

  # Nilai default (filter kosong, per_page 10, page 1) tidak ditulis ke URL.
  defp build_path(class_id, q, per_page, page) do
    params =
      %{
        "class_id" => to_string(class_id),
        "q" => to_string(q),
        "per_page" => to_string(per_page),
        "page" => to_string(page)
      }
      |> Enum.reject(fn
        {"class_id", v} -> v == ""
        {"q", v} -> v == ""
        {"per_page", v} -> v == "10"
        {"page", v} -> v == "1"
      end)
      |> Map.new()

    if params == %{}, do: ~p"/enrollments", else: ~p"/enrollments?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:enrollments}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        Enrollments
        <:subtitle>Class participants (enrollment).</:subtitle>
        <:actions>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, ["enrollments:create", "enrollments:manage"])}
            patch={~p"/enrollments/new"}
          >
            <.button variant="primary">Enroll student</.button>
          </.link>
        </:actions>
      </.header>

      <form id="enrollment-filter" phx-change="filter" class="mb-4 flex flex-wrap items-center gap-2">
        <select name="class_id" class="select select-bordered select-sm max-w-xs">
          <option value="">All classes</option>
          <option :for={{label, id} <- @class_options} value={id} selected={@class_id == id}>
            {label}
          </option>
        </select>
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="Search student name…"
          phx-debounce="300"
          class="input input-bordered input-sm w-full max-w-xs"
        />
        <select name="per_page" class="select select-bordered select-sm">
          <option :for={n <- @per_page_options} value={n} selected={@per_page == n}>
            {n} / page
          </option>
        </select>
        <.link
          :if={@class_id != "" or @q != ""}
          patch={~p"/enrollments"}
          class="btn btn-sm btn-ghost"
        >
          Reset
        </.link>
      </form>

      <.table id="enrollments" rows={@enrollments}>
        <:col :let={e} label="Student">{e.student && e.student.full_name}</:col>
        <:col :let={e} label="Class">{e.class && e.class.title}</:col>
        <:col :let={e} label="Course">{e.class && e.class.course && e.class.course.title}</:col>
        <:col :let={e} label="Status"><span class="badge badge-neutral">{e.status}</span></:col>
        <:col :let={e} label="Enrolled">{StellarWeb.Format.datetime(e.enrolled_at)}</:col>
        <:action :let={e}>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, ["enrollments:update", "enrollments:manage"])}
            phx-click="set_status"
            phx-value-id={e.id}
            phx-value-status={if e.status == :active, do: "completed", else: "active"}
            class="btn btn-ghost btn-xs"
          >
            {if e.status == :active, do: "Mark completed", else: "Activate"}
          </.link>
        </:action>
        <:action :let={e}>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, ["enrollments:delete", "enrollments:manage"])}
            phx-click="delete"
            phx-value-id={e.id}
            data-confirm="Delete this enrollment?"
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
            patch={build_path(@class_id, @q, @per_page, @page - 1)}
            class="join-item btn btn-sm"
          >
            « Previous
          </.link>
          <span :if={@page <= 1} class="join-item btn btn-sm btn-disabled">« Previous</span>
          <.link
            :if={@page < @total_pages}
            patch={build_path(@class_id, @q, @per_page, @page + 1)}
            class="join-item btn btn-sm"
          >
            Next »
          </.link>
          <span :if={@page >= @total_pages} class="join-item btn btn-sm btn-disabled">
            Next »
          </span>
        </div>
      </div>

      <div
        :if={@live_action == :new and @form != nil}
        id="enrollment-modal"
        class="modal modal-open"
      >
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">Enroll student in class</h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input
              field={@form[:class_id]}
              type="select"
              label="Class"
              options={@class_options}
              prompt="— Select class —"
              required
            />
            <.input
              field={@form[:student_id]}
              type="select"
              label="Student"
              options={@student_options}
              prompt="— Select student —"
              required
            />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Enrolling...">Enroll</.button>
              <.link patch={index_path_assign(assigns)} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={index_path_assign(assigns)} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end

  defp index_path_assign(assigns),
    do: build_path(assigns.class_id, assigns.q, assigns.per_page, assigns.page)
end
