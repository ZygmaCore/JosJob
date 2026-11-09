defmodule StellarWeb.Admin.ClassLive do
  @moduledoc """
  Menu admin Classes versi LiveView (port penuh ClassController lama):

  - `:index` — list per-tenant; kolom Instructor hanya menampilkan nama bila
    instructor pengajar sah di org class (`Teachers.teacher_pairs`).
  - `:new`/`:edit` — halaman kerja (bukan modal): form class + (edit) panel
    Peserta + Materi. Jadwal dinamis dan dropdown pengajar yang mengikuti org
    kini murni LiveView — menggantikan JS manual (data-instructors,
    schedule-row-tpl) dari versi controller.

  Gate granular dipertahankan: `classes:create/update/delete` (`classes:manage`
  superset) untuk class; `enrollments:*` untuk peserta. Superuser lintas org;
  non-superuser ter-scope org aktif. Pengajar divalidasi saat save (harus
  pengajar aktif di org class).
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Class, Course, Enrollment}
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Accounts.User

  # --- perms (identik dengan controller lama) ---

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]
  defp p(socket, list), do: StellarWeb.Perms.can?(socket.assigns[:permissions], list)

  defp can_create?(socket), do: p(socket, ["classes:create", "classes:manage"])
  defp can_update?(socket), do: p(socket, ["classes:update", "classes:manage"])
  defp can_delete?(socket), do: p(socket, ["classes:delete", "classes:manage"])

  defp can_enroll_create?(socket), do: p(socket, ["enrollments:create", "enrollments:manage"])
  defp can_enroll_update?(socket), do: p(socket, ["enrollments:update", "enrollments:manage"])
  defp can_enroll_delete?(socket), do: p(socket, ["enrollments:delete", "enrollments:manage"])

  defp can_enroll_any?(socket),
    do:
      p(socket, [
        "enrollments:read",
        "enrollments:create",
        "enrollments:update",
        "enrollments:delete",
        "enrollments:manage"
      ])

  defp in_scope?(socket, %Class{} = class),
    do: su?(socket) or class.organization_id == active_org(socket)

  defp can_open_edit?(socket, class),
    do: in_scope?(socket, class) and (can_update?(socket) or can_enroll_any?(socket))

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: socket |> assign(:class, nil) |> load_classes()

  defp apply_action(socket, :new, _params) do
    if can_create?(socket) do
      form =
        AshPhoenix.Form.for_create(Class, :create,
          as: "class",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      form_org = if su?(socket), do: "", else: active_org(socket)

      socket
      |> assign(:class, nil)
      |> assign(:form, to_form(form))
      |> assign(:schedule_rows, [blank_row()])
      |> assign(:form_org, form_org)
      |> assign(:instructor_options, instructor_options_for(form_org))
      |> assign(:instructor_value, nil)
      |> assign_form_options()
    else
      forbid(socket)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    class = Ash.get!(Class, id, authorize?: false)

    if can_open_edit?(socket, class) do
      form =
        AshPhoenix.Form.for_update(class, :update,
          as: "class",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket
      |> assign(:class, class)
      |> assign(:form, to_form(form))
      |> assign(:schedule_rows, schedule_rows(class))
      |> assign(:form_org, class.organization_id)
      |> assign(:instructor_options, instructor_options_for(class.organization_id))
      |> assign(:instructor_value, stored_instructor_value(class))
      |> assign_form_options()
      |> load_edit_panels(class)
    else
      forbid(socket)
    end
  end

  defp forbid(socket) do
    socket
    |> assign(:class, nil)
    |> put_flash(:error, "You don't have permission for that action.")
    |> push_navigate(to: ~p"/classes")
  end

  # --- events: form ---

  @impl true
  def handle_event("validate", %{"class" => params}, socket) do
    {_stored, rows} = parse_schedule(params)

    # Org di form berubah (superuser) -> opsi pengajar mengikuti org baru dan
    # pilihan lama dikosongkan (pengajar org lama tak sah di org baru).
    new_org =
      if su?(socket),
        do: to_string(params["organization_id"] || ""),
        else: active_org(socket)

    {options, value} =
      if new_org == socket.assigns.form_org do
        {socket.assigns.instructor_options, params["instructor_id"]}
      else
        {instructor_options_for(new_org), nil}
      end

    form_params = Map.drop(params, ["schedule", "after_save", "instructor_id"])

    {:noreply,
     socket
     |> assign(:form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, form_params)))
     |> assign(:schedule_rows, rows)
     |> assign(:form_org, new_org)
     |> assign(:instructor_options, options)
     |> assign(:instructor_value, value)}
  end

  def handle_event("add_session", _params, socket) do
    {:noreply, assign(socket, :schedule_rows, socket.assigns.schedule_rows ++ [blank_row()])}
  end

  def handle_event("remove_session", %{"idx" => idx}, socket) do
    rows = List.delete_at(socket.assigns.schedule_rows, String.to_integer(idx))
    rows = if rows == [], do: [blank_row()], else: rows
    {:noreply, assign(socket, :schedule_rows, rows)}
  end

  def handle_event("save", %{"class" => params}, socket) do
    allowed? =
      case socket.assigns.live_action do
        :new -> can_create?(socket)
        :edit -> can_update?(socket) and in_scope?(socket, socket.assigns.class)
      end

    if allowed?, do: do_save(socket, params), else: {:noreply, forbid(socket)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    class = Ash.get!(Class, id, authorize?: false)

    if can_delete?(socket) and in_scope?(socket, class) do
      Ash.destroy!(class, authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Class deleted.")
       |> load_classes()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  # --- events: peserta ---

  def handle_event("add_enrollment", %{"student_id" => student_id}, socket) do
    class = socket.assigns.class

    if can_enroll_create?(socket) and in_scope?(socket, class) do
      result =
        Enrollment
        |> Ash.Changeset.for_create(:create, %{class_id: class.id, student_id: student_id})
        |> Ash.create(authorize?: false)

      socket =
        case result do
          {:ok, _} ->
            put_flash(socket, :info, "Student enrolled.")

          {:error, _} ->
            put_flash(
              socket,
              :error,
              "Enrollment failed (class full or student already enrolled)."
            )
        end

      {:noreply, load_edit_panels(socket, class)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  def handle_event("remove_enrollment", %{"enr_id" => enr_id}, socket) do
    class = socket.assigns.class

    if can_enroll_delete?(socket) and in_scope?(socket, class) do
      Enrollment |> Ash.get!(enr_id, authorize?: false) |> Ash.destroy!(authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Enrollment deleted.")
       |> load_edit_panels(class)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  def handle_event("set_enrollment_status", %{"enr_id" => enr_id, "status" => status}, socket) do
    class = socket.assigns.class

    if can_enroll_update?(socket) and in_scope?(socket, class) do
      Enrollment
      |> Ash.get!(enr_id, authorize?: false)
      |> Ash.Changeset.for_update(:set_status, %{status: status})
      |> Ash.update!(authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Enrollment status updated.")
       |> load_edit_panels(class)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  defp do_save(socket, params) do
    {schedule, rows} = parse_schedule(params)

    attrs =
      params
      |> Map.drop(["schedule", "after_save"])
      |> put_org(socket)
      |> Map.put("schedule", schedule)

    target_org =
      attrs["organization_id"] || (socket.assigns.class && socket.assigns.class.organization_id)

    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    with true <- valid_instructor?(target_org, attrs["instructor_id"]),
         {:ok, class} <- AshPhoenix.Form.submit(socket.assigns.form.source, params: attrs) do
      socket = put_flash(socket, :info, "Class #{verb}.")

      cond do
        params["after_save"] == "list" ->
          {:noreply, push_navigate(socket, to: ~p"/classes")}

        socket.assigns.live_action == :new ->
          {:noreply, push_navigate(socket, to: ~p"/classes/#{class.id}/edit")}

        true ->
          # Save biasa di edit: tetap di halaman kerja, muat ulang seluruh state.
          {:noreply, apply_action(socket, :edit, %{"id" => class.id})}
      end
    else
      false ->
        form = AshPhoenix.Form.validate(socket.assigns.form.source, attrs)

        {:noreply,
         socket
         |> put_flash(:error, instructor_error())
         |> assign(:form, to_form(form))
         |> assign(:schedule_rows, rows)
         |> assign(:instructor_value, params["instructor_id"])}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> assign(:schedule_rows, rows)
         |> assign(:instructor_value, params["instructor_id"])}
    end
  end

  # --- loaders ---

  defp load_classes(socket) do
    classes =
      base_scope(socket)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load([:course, :instructor, :enrollments])
      |> Ash.read!(authorize?: false)

    socket
    |> assign(:classes, classes)
    |> assign(:org_names, org_name_map())
    |> assign(:teacher_pairs, StellarWeb.Teachers.teacher_pairs(classes))
  end

  defp base_scope(socket) do
    if su?(socket),
      do: Class,
      else: Ash.Query.filter(Class, organization_id == ^active_org(socket))
  end

  defp load_edit_panels(socket, class) do
    enrollments =
      Enrollment
      |> Ash.Query.filter(class_id == ^class.id)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load([:student])
      |> Ash.read!(authorize?: false)

    enrolled_ids = Enum.map(enrollments, & &1.student_id)
    members = org_members(class.organization_id)

    socket
    |> assign(:enrollments, enrollments)
    |> assign(
      :student_options,
      members |> Enum.reject(&(&1.id in enrolled_ids)) |> Enum.map(&user_opt/1)
    )
    |> assign(:materials, Learning.materials_for_class(class))
  end

  defp assign_form_options(socket) do
    socket
    |> assign(:org_options, org_options())
    |> assign(:course_options, course_options(socket))
  end

  # --- opsi form ---

  defp org_options do
    Organization
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.name)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp course_options(socket) do
    scope =
      if su?(socket),
        do: Course,
        else: Ash.Query.filter(Course, organizations.id == ^active_org(socket))

    scope
    |> Ash.Query.sort(title: :asc)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.title, &1.id})
  end

  # Pengajar untuk org tertentu; "" = belum ada org terpilih (superuser, form new).
  defp instructor_options_for(""), do: []

  defp instructor_options_for(org_id) do
    StellarWeb.Teachers.teacher_users(org_id)
    |> Enum.sort_by(& &1.full_name)
    |> Enum.map(&user_opt/1)
  end

  defp user_opt(u), do: {"#{u.full_name} (#{u.email})", u.id}

  defp org_members(nil), do: []

  defp org_members(org_id) do
    member_ids =
      Membership
      |> Ash.Query.filter(organization_id == ^org_id and status == :active)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)

    User
    |> Ash.Query.filter(id in ^member_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.full_name)
  end

  defp org_name_map do
    Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end

  # --- instructor: aturan sama dengan kolom Pengajar (teacher_pairs) ---

  defp stored_instructor_value(class) do
    pairs = StellarWeb.Teachers.teacher_pairs([class])

    if MapSet.member?(pairs, {class.organization_id, class.instructor_id}),
      do: class.instructor_id,
      else: nil
  end

  defp valid_instructor?(org_id, instructor_id) do
    is_binary(instructor_id) and instructor_id != "" and is_binary(org_id) and
      Enum.any?(StellarWeb.Teachers.teacher_users(org_id), &(&1.id == instructor_id))
  end

  defp instructor_error,
    do: "The selected instructor is not an active teacher in this class's organization."

  # Non-superuser: paksa org class ke org aktifnya.
  defp put_org(attrs, socket) do
    if su?(socket), do: attrs, else: Map.put(attrs, "organization_id", active_org(socket))
  end

  # --- schedule (jsonb; dua bentuk per sesi) — port verbatim dari controller ---

  def blank_row,
    do: %{
      "recurring" => false,
      "start_date" => "",
      "end_date" => "",
      "day" => "",
      "start_hour" => "",
      "start_minute" => "",
      "end_hour" => "",
      "end_minute" => ""
    }

  defp schedule_rows(%Class{schedule: list}) when is_list(list) and list != [] do
    Enum.map(list, &normalize_row/1)
  end

  defp schedule_rows(_), do: [blank_row()]

  defp normalize_row(m) do
    if truthy(mget(m, "recurring")) do
      {sh, sm} = split_time(mget(m, "start_time"))
      {eh, em} = split_time(mget(m, "end_time"))

      %{
        "recurring" => true,
        "start_date" => "",
        "end_date" => "",
        "day" => to_string(mget(m, "day") || ""),
        "start_hour" => sh,
        "start_minute" => sm,
        "end_hour" => eh,
        "end_minute" => em
      }
    else
      {sd, sh, sm} = split_dt(mget(m, "start_date"))
      {ed, eh, em} = split_dt(mget(m, "end_date"))

      %{
        "recurring" => false,
        "start_date" => sd,
        "end_date" => ed,
        "day" => "",
        "start_hour" => sh,
        "start_minute" => sm,
        "end_hour" => eh,
        "end_minute" => em
      }
    end
  end

  defp split_time(t) do
    case String.split(to_string(t || ""), ":") do
      [h, m | _] -> {h, m}
      _ -> {"", ""}
    end
  end

  defp split_dt(v) do
    s = to_string(v || "")

    case String.split(s, "T") do
      [date, time | _] ->
        {h, m} = split_time(time)
        {date, h, m}

      _ ->
        {s, "", ""}
    end
  end

  defp combine_time(hour, minute) do
    if to_string(hour) == "",
      do: "",
      else: "#{hour}:#{if to_string(minute) == "", do: "00", else: minute}"
  end

  defp combine_dt(date, hour, minute) do
    if to_string(date) == "", do: "", else: "#{date}T#{time_or_zero(hour, minute)}"
  end

  defp time_or_zero(hour, minute) do
    case combine_time(hour, minute) do
      "" -> "00:00"
      t -> t
    end
  end

  defp mget(m, key), do: Map.get(m, key)

  defp parse_schedule(params) do
    raw =
      case Map.get(params, "schedule") do
        %{} = m -> m |> Enum.sort_by(fn {k, _} -> k end) |> Enum.map(fn {_, v} -> v end)
        list when is_list(list) -> list
        _ -> []
      end

    rows =
      Enum.map(raw, fn r ->
        %{
          "recurring" => truthy(r["recurring"]),
          "start_date" => to_string(r["start_date"] || ""),
          "end_date" => to_string(r["end_date"] || ""),
          "day" => to_string(r["day"] || ""),
          "start_hour" => to_string(r["start_hour"] || ""),
          "start_minute" => to_string(r["start_minute"] || ""),
          "end_hour" => to_string(r["end_hour"] || ""),
          "end_minute" => to_string(r["end_minute"] || "")
        }
      end)

    kept = rows |> Enum.map(&to_stored/1) |> Enum.reject(&is_nil/1)
    rows = if rows == [], do: [blank_row()], else: rows
    {kept, rows}
  end

  defp to_stored(%{"recurring" => true} = r) do
    if r["day"] == "",
      do: nil,
      else: %{
        "recurring" => true,
        "day" => r["day"],
        "start_time" => combine_time(r["start_hour"], r["start_minute"]),
        "end_time" => combine_time(r["end_hour"], r["end_minute"])
      }
  end

  defp to_stored(%{"recurring" => false} = r) do
    if r["start_date"] == "",
      do: nil,
      else: %{
        "recurring" => false,
        "start_date" => combine_dt(r["start_date"], r["start_hour"], r["start_minute"]),
        "end_date" => combine_dt(r["end_date"], r["end_hour"], r["end_minute"])
      }
  end

  defp truthy(v), do: v in [true, "true", "on", "1"]

  # --- render ---

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:classes}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        Classes
        <:subtitle>Classes (course delivery by an instructor).</:subtitle>
        <:actions>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, ["classes:create", "classes:manage"])}
            navigate={~p"/classes/new"}
          >
            <.button variant="primary">New class</.button>
          </.link>
        </:actions>
      </.header>

      <.table id="classes" rows={@classes}>
        <:col :let={c} label="Course">{c.course && c.course.title}</:col>
        <:col :let={c} label="Title">{c.title}</:col>
        <:col :let={c} label="Instructor">
          <.instructor_cell row={c} teacher_pairs={@teacher_pairs} />
        </:col>
        <:col :let={c} label="Tenant">{@org_names[c.organization_id]}</:col>
        <:col :let={c} label="Sessions">{length(c.schedule)}</:col>
        <:col :let={c} label="Capacity">{c.capacity || "∞"}</:col>
        <:col :let={c} label="Enrolled">{length(c.enrollments)}</:col>
        <:action :let={c}>
          <.link
            :if={
              StellarWeb.Perms.can?(@permissions, [
                "classes:update",
                "classes:manage",
                "enrollments:read",
                "enrollments:create",
                "enrollments:update",
                "enrollments:delete",
                "enrollments:manage"
              ])
            }
            navigate={~p"/classes/#{c.id}/edit"}
            class="btn btn-ghost btn-xs"
          >
            Edit
          </.link>
        </:action>
        <:action :let={c}>
          <.link
            :if={StellarWeb.Perms.can?(@permissions, ["classes:delete", "classes:manage"])}
            phx-click="delete"
            phx-value-id={c.id}
            data-confirm="Delete this class?"
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
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
      active={:classes}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <.header>
        {if @live_action == :new, do: "New class", else: "Edit class"}
        <:subtitle :if={@class}>{@class.title}</:subtitle>
      </.header>

      <.class_form
        :if={
          @live_action == :new or
            StellarWeb.Perms.can?(@permissions, ["classes:update", "classes:manage"])
        }
        form={@form}
        superuser={@permissions == :all}
        org_id={@active_organization_id}
        form_org={@form_org}
        org_options={@org_options}
        course_options={@course_options}
        instructor_options={@instructor_options}
        instructor_value={@instructor_value}
        schedule_rows={@schedule_rows}
        submit_label={if @live_action == :new, do: "Create", else: "Save"}
      />

      <%= if @live_action == :edit do %>
        <div class="divider"></div>

        <section class="space-y-4">
          <h2 class="text-lg font-semibold">Participants (enrollment)</h2>

          <.table id="enrollments" rows={@enrollments}>
            <:col :let={e} label="Student">{e.student && e.student.full_name}</:col>
            <:col :let={e} label="Status">{e.status}</:col>
            <:col :let={e} label="Enrolled">{StellarWeb.Format.datetime(e.enrolled_at)}</:col>
            <:action :let={e}>
              <.link
                :if={
                  StellarWeb.Perms.can?(@permissions, ["enrollments:update", "enrollments:manage"])
                }
                phx-click="set_enrollment_status"
                phx-value-enr_id={e.id}
                phx-value-status={if e.status == :active, do: "completed", else: "active"}
                class="btn btn-ghost btn-xs"
              >
                {if e.status == :active, do: "Mark completed", else: "Activate"}
              </.link>
            </:action>
            <:action :let={e}>
              <.link
                :if={
                  StellarWeb.Perms.can?(@permissions, ["enrollments:delete", "enrollments:manage"])
                }
                phx-click="remove_enrollment"
                phx-value-enr_id={e.id}
                data-confirm="Delete this enrollment?"
                class="btn btn-ghost btn-xs text-error"
              >
                Delete
              </.link>
            </:action>
          </.table>

          <form
            :if={
              @student_options != [] and
                StellarWeb.Perms.can?(@permissions, ["enrollments:create", "enrollments:manage"])
            }
            id="enroll-form"
            phx-submit="add_enrollment"
            class="flex items-end gap-2"
          >
            <select name="student_id" class="select select-bordered select-sm">
              <option :for={{label, id} <- @student_options} value={id}>{label}</option>
            </select>
            <button class="btn btn-sm btn-primary">Enroll student</button>
          </form>
          <p :if={@student_options == []} class="text-sm opacity-70">
            No org members available to enroll (everyone is already enrolled / no members yet).
          </p>
        </section>

        <div class="divider"></div>

        <section class="space-y-2">
          <h2 class="text-lg font-semibold">Effective class materials</h2>
          <p class="text-sm opacity-70">
            Course materials + instructor materials. Instructor materials are managed via <.link
              navigate={~p"/my/documents"}
              class="link"
            >My Documents</.link>.
          </p>
          <.table id="class-materials" rows={@materials}>
            <:col :let={m} label="Title">{m.title}</:col>
            <:col :let={m} label="Type">{m.mime_type}</:col>
            <:col :let={m} label="URL">
              <a href={m.url} target="_blank" class="link">{m.url}</a>
            </:col>
          </.table>
        </section>
      <% end %>
    </Layouts.admin>
    """
  end

  # Kolom "Instructor": nama hanya bila instructor pengajar aktif di org class.
  attr :row, :map, required: true
  attr :teacher_pairs, :any, required: true

  def instructor_cell(assigns) do
    %{row: row} = assigns
    teacher? = MapSet.member?(assigns.teacher_pairs, {row.organization_id, row.instructor_id})
    assigns = assign(assigns, :name, teacher? && row.instructor && row.instructor.full_name)

    ~H"""
    <span :if={@name}>{@name}</span>
    <span :if={!@name} class="opacity-60">— no instructor —</span>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :superuser, :boolean, required: true
  attr :org_id, :string, default: nil
  attr :form_org, :string, required: true
  attr :org_options, :list, required: true
  attr :course_options, :list, required: true
  attr :instructor_options, :list, required: true
  attr :instructor_value, :any, required: true
  attr :schedule_rows, :list, required: true
  attr :submit_label, :string, required: true

  def class_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="class-form"
      phx-change="validate"
      phx-submit="save"
      class="max-w-3xl space-y-5"
    >
      <input :if={not @superuser} type="hidden" name="class[organization_id]" value={@org_id} />

      <.input
        :if={@superuser}
        field={@form[:organization_id]}
        type="select"
        label="Organization (tenant)"
        options={@org_options}
        value={@form_org}
        prompt="— Select tenant —"
        required
      />
      <.input
        field={@form[:course_id]}
        type="select"
        label="Course"
        options={@course_options}
        prompt="— Select course —"
        required
      />
      <.input
        field={@form[:instructor_id]}
        type="select"
        label="Instructor"
        options={@instructor_options}
        value={@instructor_value}
        prompt="— Select instructor —"
        required
        disabled={@superuser and @form_org == ""}
      />
      <.input field={@form[:title]} type="text" label="Class title (optional)" />
      <.input field={@form[:capacity]} type="number" label="Capacity (empty = unlimited)" />

      <fieldset class="fieldset">
        <legend class="fieldset-legend">Schedule (sessions)</legend>
        <p class="mb-1 text-xs opacity-60">
          Check <b>Recurring</b>
          for a repeating session (pick day + time); unchecked = specific date & time.
        </p>
        <div id="schedule-rows" class="space-y-2 overflow-x-auto">
          <.schedule_row
            :for={{row, i} <- Enum.with_index(@schedule_rows)}
            idx={Integer.to_string(i)}
            row={row}
          />
        </div>
        <button type="button" class="btn btn-outline btn-sm mt-2 w-fit" phx-click="add_session">
          + Add session
        </button>
      </fieldset>

      <div class="flex items-center gap-3">
        <.button variant="primary" phx-disable-with="Saving...">{@submit_label}</.button>
        <button type="submit" name="class[after_save]" value="list" class="btn">
          Save & back to list
        </button>
        <.link navigate={~p"/classes"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end

  # Satu baris jadwal — mode ditentukan row["recurring"]; toggle checkbox memicu
  # phx-change (validate) sehingga baris dirender ulang di mode yang benar
  # (menggantikan JS scheduleToggle lama).
  attr :idx, :string, required: true
  attr :row, :map, required: true

  def schedule_row(assigns) do
    ~H"""
    <div class="flex flex-nowrap items-center gap-1 whitespace-nowrap rounded-lg border border-base-300 bg-base-200/60 p-2">
      <label
        class="flex shrink-0 cursor-pointer items-center gap-1.5 text-sm"
        title="Repeating session (day + time)"
      >
        <input
          type="checkbox"
          name={"class[schedule][#{@idx}][recurring]"}
          value="true"
          checked={@row["recurring"]}
          class="checkbox checkbox-sm"
        /> Recurring
      </label>

      <span class="mx-1 h-6 w-px shrink-0 bg-base-300"></span>

      <%= if @row["recurring"] do %>
        <select
          name={"class[schedule][#{@idx}][day]"}
          class="select select-bordered select-sm w-32 shrink-0"
        >
          <option value="">— Day —</option>
          <option :for={{label, val} <- day_options()} value={val} selected={@row["day"] == val}>
            {label}
          </option>
        </select>
      <% else %>
        <input
          type="date"
          name={"class[schedule][#{@idx}][start_date]"}
          value={@row["start_date"]}
          class="input input-bordered input-sm w-28 shrink-0 px-1"
        />
      <% end %>

      <span class="inline-flex shrink-0 items-center gap-0.5">
        <select
          name={"class[schedule][#{@idx}][start_hour]"}
          class="select select-bordered select-sm w-16 px-1"
        >
          <option value="">HH</option>
          <option :for={h <- hour_options()} value={h} selected={@row["start_hour"] == h}>{h}</option>
        </select>
        <span class="opacity-60">:</span>
        <select
          name={"class[schedule][#{@idx}][start_minute]"}
          class="select select-bordered select-sm w-16 px-1"
        >
          <option value="">MM</option>
          <option :for={m <- minute_options()} value={m} selected={@row["start_minute"] == m}>
            {m}
          </option>
        </select>
      </span>

      <span class="shrink-0 px-0.5 opacity-60">→</span>

      <input
        :if={!@row["recurring"]}
        type="date"
        name={"class[schedule][#{@idx}][end_date]"}
        value={@row["end_date"]}
        class="input input-bordered input-sm w-28 shrink-0 px-1"
      />

      <span class="inline-flex shrink-0 items-center gap-0.5">
        <select
          name={"class[schedule][#{@idx}][end_hour]"}
          class="select select-bordered select-sm w-16 px-1"
        >
          <option value="">HH</option>
          <option :for={h <- hour_options()} value={h} selected={@row["end_hour"] == h}>{h}</option>
        </select>
        <span class="opacity-60">:</span>
        <select
          name={"class[schedule][#{@idx}][end_minute]"}
          class="select select-bordered select-sm w-16 px-1"
        >
          <option value="">MM</option>
          <option :for={m <- minute_options()} value={m} selected={@row["end_minute"] == m}>
            {m}
          </option>
        </select>
      </span>

      <button
        type="button"
        class="btn btn-ghost btn-xs ml-auto shrink-0 text-error"
        title="Remove session"
        phx-click="remove_session"
        phx-value-idx={@idx}
        aria-label="Remove session"
      >
        ✕
      </button>
    </div>
    """
  end

  defp day_options,
    do: [
      {"Monday", "mon"},
      {"Tuesday", "tue"},
      {"Wednesday", "wed"},
      {"Thursday", "thu"},
      {"Friday", "fri"},
      {"Saturday", "sat"},
      {"Sunday", "sun"}
    ]

  defp hour_options, do: Enum.map(0..23, &pad2/1)
  defp minute_options, do: Enum.map(0..59, &pad2/1)
  defp pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
