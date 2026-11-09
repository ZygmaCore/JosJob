defmodule StellarWeb.Admin.TeacherLive do
  @moduledoc """
  Menu Teachers versi LiveView (spec: docs/specs/2026-07-27-teachers-menu-design.md).
  Read-only: `:index` (list per pasangan org+user) dan `:show` (detail class yang
  diajar + peserta aktif + jadwal). "Teacher" = user ber-membership aktif yang
  mengemban role `teacher` (sumber tunggal: `StellarWeb.Teachers`). Detail
  me-resolve dari sumber yang SAMA dengan index — setiap baris list pasti bisa
  dibuka. Aksi delete sengaja tidak ada (dibatalkan: `Class.instructor_id`
  non-nullable).
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias StellarLrn.Learning.{Class, Enrollment}
  alias Stellar.Orgs.Organization
  alias StellarWeb.Teachers

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    org_id = if su?(socket), do: nil, else: active_org(socket)
    # Non-superuser tanpa org aktif: jangan fail-open ke semua org.
    rows = if su?(socket) or org_id, do: Teachers.teacher_rows(org_id), else: []

    socket
    |> assign(:rows, rows)
    |> assign(:classes_by, classes_by(rows))
    |> assign(:org_names, org_name_map())
  end

  defp apply_action(socket, :show, %{"id" => user_id} = params) do
    org_id = resolve_org(socket, params)
    row = org_id && find_row(socket, org_id, user_id)

    if teacher = row && row.user do
      classes =
        Class
        |> Ash.Query.filter(organization_id == ^org_id and instructor_id == ^user_id)
        |> Ash.Query.sort(created_at: :asc)
        |> Ash.Query.load([:course])
        |> Ash.read!(authorize?: false)

      socket
      |> assign(:teacher, teacher)
      |> assign(:org_id, org_id)
      |> assign(:org_name, org_name_map()[org_id])
      |> assign(:classes, classes)
      |> assign(:counts, active_counts(classes))
      |> assign(:can_open_class, can_open_class?(socket))
    else
      socket
      |> put_flash(:error, "Teacher not found in that organization.")
      |> push_navigate(to: ~p"/teachers")
    end
  end

  # Konteks org: non-superuser selalu org aktif; superuser via ?org= (link dari
  # list selalu membawanya), fallback org aktif.
  defp resolve_org(socket, params) do
    if su?(socket), do: params["org"] || active_org(socket), else: active_org(socket)
  end

  # Resolve dari sumber yang SAMA dengan index (scope nil untuk superuser).
  defp find_row(socket, org_id, user_id) do
    scope = if su?(socket), do: nil, else: org_id

    Teachers.teacher_rows(scope)
    |> Enum.find(&(&1.organization_id == org_id and &1.user.id == user_id))
  end

  # Map {organization_id, user_id} => [class] (load course untuk judul).
  defp classes_by([]), do: %{}

  defp classes_by(rows) do
    org_ids = rows |> Enum.map(& &1.organization_id) |> Enum.uniq()
    user_ids = rows |> Enum.map(& &1.user.id) |> Enum.uniq()

    Class
    |> Ash.Query.filter(organization_id in ^org_ids and instructor_id in ^user_ids)
    |> Ash.Query.sort(created_at: :asc)
    |> Ash.Query.load([:course])
    |> Ash.read!(authorize?: false)
    |> Enum.group_by(&{&1.organization_id, &1.instructor_id})
  end

  # Peserta aktif per class (status :active; :completed tidak dihitung).
  defp active_counts(classes) do
    Map.new(classes, fn c ->
      n =
        Enrollment
        |> Ash.Query.filter(class_id == ^c.id and status == :active)
        |> Ash.count!(authorize?: false)

      {c.id, n}
    end)
  end

  # Boleh membuka /classes/:id/edit? — daftar izin yang sama dengan tombol Edit
  # di list Classes.
  defp can_open_class?(socket) do
    StellarWeb.Perms.can?(socket.assigns[:permissions], [
      "classes:update",
      "classes:manage",
      "enrollments:read",
      "enrollments:create",
      "enrollments:update",
      "enrollments:delete",
      "enrollments:manage"
    ])
  end

  defp org_name_map do
    Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end

  # --- helper tampilan (port dari TeacherHTML lama) ---

  def classes_of(classes_by, row), do: Map.get(classes_by, {row.organization_id, row.user.id}, [])

  def class_label(c), do: c.title || (c.course && c.course.title) || "(untitled)"

  def class_summary([]), do: "-"

  def class_summary(classes) do
    {head, rest} = Enum.split(classes, 3)
    base = head |> Enum.map(&class_label/1) |> Enum.join(", ")
    if rest == [], do: base, else: "#{base} +#{length(rest)} more"
  end

  def participants_label(n, nil), do: to_string(n)
  def participants_label(n, capacity), do: "#{n}/#{capacity}"

  def session_label(s) do
    if s["recurring"] in [true, "true"] do
      "#{day_label(s["day"])} #{s["start_time"]}–#{s["end_time"]}"
    else
      "#{fmt_dt(s["start_date"])} → #{fmt_dt(s["end_date"])}"
    end
  end

  defp fmt_dt(v), do: v |> to_string() |> String.replace("T", " ")

  defp day_label(d) do
    Map.get(
      %{
        "mon" => "Monday",
        "tue" => "Tuesday",
        "wed" => "Wednesday",
        "thu" => "Thursday",
        "fri" => "Friday",
        "sat" => "Saturday",
        "sun" => "Sunday"
      },
      to_string(d),
      to_string(d)
    )
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:teachers}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        Teachers
        <:subtitle>
          Active teachers (users holding the teacher role) & the classes they teach.
        </:subtitle>
      </.header>

      <.table id="teachers" rows={@rows}>
        <:col :let={r} label="Name">
          <div>{r.user.full_name}</div>
          <div class="text-xs opacity-60">{r.user.email}</div>
        </:col>
        <:col :let={r} label="Class">{class_summary(classes_of(@classes_by, r))}</:col>
        <:col :let={r} label="Tenant">{@org_names[r.organization_id]}</:col>
        <:action :let={r}>
          <.link
            navigate={~p"/teachers/#{r.user.id}?org=#{r.organization_id}"}
            class="btn btn-ghost btn-xs"
          >
            Detail
          </.link>
        </:action>
      </.table>
    </Layouts.admin>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:teachers}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        {@teacher.full_name}
        <:subtitle>{@teacher.email} — {@org_name}</:subtitle>
        <:actions>
          <.link navigate={~p"/teachers"} class="btn btn-ghost">Back</.link>
        </:actions>
      </.header>

      <p :if={@classes == []} class="opacity-60">Not teaching any classes yet.</p>

      <div :for={c <- @classes} class="card bg-base-200 mb-4">
        <div class="card-body">
          <h3 class="card-title text-base">
            <.link :if={@can_open_class} navigate={~p"/classes/#{c.id}/edit"} class="link">
              {class_label(c)}
            </.link>
            <span :if={!@can_open_class}>{class_label(c)}</span>
          </h3>
          <p class="text-sm opacity-70">Course: {c.course && c.course.title}</p>
          <p class="text-sm">Active participants: {participants_label(@counts[c.id], c.capacity)}</p>
          <div class="text-sm">
            <span class="font-medium">Schedule:</span>
            <ul :if={c.schedule != []} class="list-inside list-disc">
              <li :for={s <- c.schedule}>{session_label(s)}</li>
            </ul>
            <span :if={c.schedule == []} class="opacity-60">no schedule yet.</span>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
