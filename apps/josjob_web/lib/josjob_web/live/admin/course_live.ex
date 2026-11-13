defmodule JosjobWeb.Admin.CourseLive do
  @moduledoc """
  Menu admin Courses (per-tenant) versi LiveView. Route gate `courses:read`;
  create/edit/delete butuh permission granular courses:create/update/delete
  (`courses:manage` = superset). Superuser lihat semua + bagikan ke banyak
  tenant; non-superuser hanya course yang tertaut ke org aktifnya, dan course
  baru otomatis tertaut ke org aktif. Industri = M:N (checkbox). Section =
  dropdown semua section aktif.

  Halaman edit adalah full-page workspace (bukan modal, beda dari menu lain)
  karena berisi panel Materi: documents (JosjobDoc) dengan `course_id` =
  course ini — bisa ditambah baru, ditautkan dari bank org, atau dilepas.
  """
  use JosjobWeb, :live_view

  require Ash.Query

  alias Josjob.Orgs.{Industry, Organization}
  alias JosjobDoc.Documents.Document
  alias JosjobLrn.Learning.{Course, CourseIndustry, CourseOrganization, Section}

  defp su?(socket), do: socket.assigns[:permissions] == :all
  defp active_org(socket), do: socket.assigns[:active_organization_id]

  # Permission granular; `courses:manage` = superset (mencakup create/update/delete).
  defp can_create?(socket),
    do: JosjobWeb.Perms.can?(socket.assigns[:permissions], ["courses:create", "courses:manage"])

  defp can_update?(socket),
    do: JosjobWeb.Perms.can?(socket.assigns[:permissions], ["courses:update", "courses:manage"])

  defp can_delete?(socket),
    do: JosjobWeb.Perms.can?(socket.assigns[:permissions], ["courses:delete", "courses:manage"])

  # Scope tenant (superuser semua; non-superuser hanya course di org aktif).
  defp in_scope?(socket, course_id), do: su?(socket) or in_active_org?(socket, course_id)

  # Course tertaut ke org aktif? (untuk izin edit non-superuser).
  defp in_active_org?(socket, course_id) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id and organization_id == ^active_org(socket))
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  # Boleh edit course (+ materinya): punya courses:update dan dalam scope tenant.
  defp editable?(socket, course_id),
    do: can_update?(socket) and in_scope?(socket, course_id)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:audit_labels, JosjobWeb.Audit.user_labels())
     |> assign(:section_options, section_options())
     |> assign(
       :industry_options,
       Industry |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.name)
     )
     |> assign(
       :org_options,
       Organization |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.name)
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> load_courses()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    if can_create?(socket) do
      form =
        AshPhoenix.Form.for_create(Course, :create,
          as: "course",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket
      |> assign(:form, to_form(form))
      |> assign(:industry_checked, [])
      |> assign(:org_checked, [])
    else
      forbid(socket)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    if editable?(socket, id) do
      course = Ash.get!(Course, id, authorize?: false)

      form =
        AshPhoenix.Form.for_update(course, :update,
          as: "course",
          authorize?: false,
          actor: socket.assigns.current_user
        )

      socket
      |> assign(:course, course)
      |> assign(:form, to_form(form))
      |> assign(:industry_checked, course_industry_ids(id))
      |> assign(:org_checked, course_org_ids(id))
      |> assign(:materials, materials(id))
      |> assign(:linkable, linkable_docs(socket))
      |> assign(:material_form, to_form(material_create_form()))
    else
      forbid(socket)
    end
  end

  defp forbid(socket) do
    socket
    |> assign(:form, nil)
    |> put_flash(:error, "You don't have permission for that action.")
    |> push_patch(to: ~p"/courses")
  end

  @impl true
  def handle_event("validate", %{"course" => params}, socket) do
    {industry_ids, org_ids, attrs} = pop_join_ids(socket, params)

    {:noreply,
     socket
     |> assign(:form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, attrs)))
     |> assign(:industry_checked, industry_ids)
     |> assign(:org_checked, org_ids)}
  end

  def handle_event("save", %{"course" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"
    {industry_ids, org_ids, attrs} = pop_join_ids(socket, params)

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: attrs) do
      {:ok, course} ->
        sync_industries(course.id, industry_ids)

        # Create: org_ids sudah dipaksa ke org aktif (non-su) oleh pop_join_ids.
        # Update: non-superuser tidak boleh mengubah tautan tenant (biarkan apa
        # adanya).
        if socket.assigns.live_action == :new or su?(socket),
          do: sync_organizations(course.id, org_ids)

        {:noreply,
         socket
         |> put_flash(:info, "Course #{course.title} #{verb}.")
         |> push_patch(to: ~p"/courses")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> assign(:industry_checked, industry_ids)
         |> assign(:org_checked, org_ids)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    if can_delete?(socket) and in_scope?(socket, id) do
      course = Ash.get!(Course, id, authorize?: false)
      # Lepas materi (documents.course_id) agar tak jadi orphan; join M:N drop via FK.
      detach_all_materials(id)

      case Ash.destroy(course, authorize?: false) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:info, "Course #{course.title} deleted.")
           |> load_courses()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete course.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  # --- materials ---

  def handle_event("add_material", %{"document" => params}, socket) do
    course_id = socket.assigns.course.id

    cond do
      not editable?(socket, course_id) ->
        {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}

      # Materi butuh tenant. Non-superuser: org aktif. Superuser (tanpa org aktif):
      # ambil tenant course. Course tanpa tenant → tak bisa dibuatkan materi.
      is_nil(material_org_id(socket, course_id)) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Course isn't linked to any tenant yet — link it in the course form first, then add material."
         )}

      true ->
        attrs =
          params
          |> Map.put("course_id", course_id)
          |> Map.put("organization_id", material_org_id(socket, course_id))
          |> Map.put("user_id", socket.assigns.current_user.id)

        case AshPhoenix.Form.submit(material_create_form(), params: attrs) do
          {:ok, _doc} ->
            {:noreply,
             socket
             |> put_flash(:info, "Material added.")
             |> assign(:materials, materials(course_id))
             |> assign(:linkable, linkable_docs(socket))
             |> assign(:material_form, to_form(material_create_form()))}

          {:error, _form} ->
            {:noreply, put_flash(socket, :error, "Failed to add material (check title & URL).")}
        end
    end
  end

  def handle_event("link_material", %{"document_id" => doc_id}, socket) do
    course_id = socket.assigns.course.id

    if editable?(socket, course_id) do
      Document
      |> Ash.get!(doc_id, authorize?: false)
      |> Ash.Changeset.for_update(:update, %{course_id: course_id})
      |> Ash.update!(authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Document linked as material.")
       |> assign(:materials, materials(course_id))
       |> assign(:linkable, linkable_docs(socket))}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  def handle_event("detach_material", %{"doc_id" => doc_id}, socket) do
    course_id = socket.assigns.course.id

    if editable?(socket, course_id) do
      Document
      |> Ash.get!(doc_id, authorize?: false)
      |> Ash.Changeset.for_update(:update, %{course_id: nil})
      |> Ash.update!(authorize?: false)

      {:noreply,
       socket
       |> put_flash(:info, "Material removed.")
       |> assign(:materials, materials(course_id))
       |> assign(:linkable, linkable_docs(socket))}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission for that action.")}
    end
  end

  # Tenant untuk materi course: org aktif bila ada (non-superuser); jika tak ada
  # (superuser), pakai tenant pertama yang tertaut ke course. nil bila course
  # belum punya tenant.
  defp material_org_id(socket, course_id) do
    active_org(socket) || first_course_org(course_id)
  end

  defp first_course_org(course_id) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.Query.sort(id: :asc)
    |> Ash.read!(authorize?: false)
    |> List.first()
    |> case do
      nil -> nil
      co -> co.organization_id
    end
  end

  # --- data / forms ---

  defp load_courses(socket) do
    courses =
      base_scope(socket)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load([:section, :industries])
      |> Ash.read!(authorize?: false)

    assign(socket, :courses, courses)
  end

  # Superuser lihat semua; non-superuser hanya course yang tertaut ke org aktif.
  defp base_scope(socket) do
    if su?(socket),
      do: Course,
      else: Ash.Query.filter(Course, organizations.id == ^active_org(socket))
  end

  defp material_create_form,
    do: AshPhoenix.Form.for_create(Document, :create, as: "document", authorize?: false)

  defp section_options do
    Section
    |> Ash.Query.filter(is_active == true)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.name, &1.id})
  end

  # Pisahkan industry_ids/organization_ids dari atribut course. Non-superuser:
  # abaikan org yang dikirim, paksa ke org aktif.
  defp pop_join_ids(socket, params) do
    industry_ids = params |> Map.get("industry_ids", []) |> List.wrap() |> clean_ids()

    org_ids =
      if su?(socket),
        do: params |> Map.get("organization_ids", []) |> List.wrap() |> clean_ids(),
        else: [active_org(socket)]

    {industry_ids, org_ids, Map.drop(params, ["industry_ids", "organization_ids"])}
  end

  defp clean_ids(ids), do: Enum.reject(ids, &(&1 in ["", nil]))

  # Set join agar persis = ids (hapus semua, buat ulang) — pola sama seperti RoleLive.
  defp sync_industries(course_id, ids) do
    CourseIndustry
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    Enum.each(ids, fn iid ->
      CourseIndustry
      |> Ash.Changeset.for_create(:create, %{course_id: course_id, industry_id: iid})
      |> Ash.create!(authorize?: false)
    end)
  end

  defp sync_organizations(course_id, ids) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    Enum.each(ids, fn oid ->
      CourseOrganization
      |> Ash.Changeset.for_create(:create, %{course_id: course_id, organization_id: oid})
      |> Ash.create!(authorize?: false)
    end)
  end

  defp course_industry_ids(course_id) do
    CourseIndustry
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.industry_id)
  end

  defp course_org_ids(course_id) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.organization_id)
  end

  defp materials(course_id) do
    Document
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  # Dokumen bank milik org aktif yang belum tertaut ke course mana pun.
  defp linkable_docs(socket) do
    Document
    |> Ash.Query.filter(organization_id == ^active_org(socket) and is_nil(course_id))
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  defp detach_all_materials(course_id) do
    Document
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn doc ->
      doc
      |> Ash.Changeset.for_update(:update, %{course_id: nil})
      |> Ash.update!(authorize?: false)
    end)
  end

  # --- form component (dipakai modal New & workspace Edit) ---

  attr :form, Phoenix.HTML.Form, required: true
  attr :submit_label, :string, required: true
  attr :superuser, :boolean, required: true
  attr :section_options, :list, required: true
  attr :industry_options, :list, required: true
  attr :org_options, :list, required: true
  attr :industry_checked, :list, required: true
  attr :org_checked, :list, required: true
  attr :cancel_patch, :string, required: true

  defp course_form(assigns) do
    ~H"""
    <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-5">
      <.input
        field={@form[:section_id]}
        type="select"
        label="Section"
        options={@section_options}
        prompt="— Select section —"
        required
      />
      <.input field={@form[:title]} type="text" label="Course title" required />
      <.input field={@form[:description]} type="textarea" label="Description" rows="3" />
      <.input field={@form[:is_active]} type="checkbox" label="Active" />
      <.input
        field={@form[:is_public]}
        type="checkbox"
        label="Public (all students can see it, no need to be an org member)"
      />

      <fieldset class="fieldset">
        <legend class="fieldset-legend">Industries</legend>
        <div class="flex flex-wrap gap-3">
          <label :for={i <- @industry_options} class="flex items-center gap-2">
            <input
              type="checkbox"
              name="course[industry_ids][]"
              value={i.id}
              checked={i.id in @industry_checked}
              class="checkbox checkbox-sm"
            />
            {i.name}
          </label>
        </div>
      </fieldset>

      <fieldset :if={@superuser} class="fieldset">
        <legend class="fieldset-legend">Share with tenant</legend>
        <div class="flex flex-wrap gap-3">
          <label :for={o <- @org_options} class="flex items-center gap-2">
            <input
              type="checkbox"
              name="course[organization_ids][]"
              value={o.id}
              checked={o.id in @org_checked}
              class="checkbox checkbox-sm"
            />
            {o.name}
          </label>
        </div>
      </fieldset>

      <div class="flex items-center gap-3">
        <.button variant="primary" phx-disable-with="Saving...">{@submit_label}</.button>
        <.link patch={@cancel_patch} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      active={:courses}
      current_user={@current_user}
      permissions={@permissions}
      active_organization_id={@active_organization_id}
      member_orgs={@member_orgs}
    >
      <div :if={@live_action == :edit}>
        <.header>
          Edit course
          <:subtitle>{@course.title}</:subtitle>
        </.header>

        <.course_form
          form={@form}
          submit_label="Save"
          superuser={@permissions == :all}
          section_options={@section_options}
          industry_options={@industry_options}
          org_options={@org_options}
          industry_checked={@industry_checked}
          org_checked={@org_checked}
          cancel_patch={~p"/courses"}
        />

        <div class="divider"></div>

        <section class="space-y-4">
          <h2 class="text-lg font-semibold">Course materials</h2>

          <.table id="materials" rows={@materials}>
            <:col :let={m} label="Title">{m.title}</:col>
            <:col :let={m} label="Type">{m.mime_type}</:col>
            <:col :let={m} label="URL">
              <a href={m.url} target="_blank" class="link">{m.url}</a>
            </:col>
            <:action :let={m}>
              <.link
                phx-click="detach_material"
                phx-value-doc_id={m.id}
                data-confirm="Remove this material from the course?"
                class="btn btn-ghost btn-xs text-error"
              >
                Remove
              </.link>
            </:action>
          </.table>

          <div class="grid gap-6 md:grid-cols-2">
            <div>
              <h3 class="mb-2 font-medium">Add new material</h3>
              <.form for={@material_form} phx-submit="add_material" class="space-y-3">
                <.input field={@material_form[:title]} type="text" label="Title" required />
                <.input field={@material_form[:url]} type="text" label="URL" required />
                <.input field={@material_form[:mime_type]} type="text" label="Type (mime)" />
                <.input
                  field={@material_form[:description]}
                  type="textarea"
                  label="Description"
                  rows="2"
                />
                <.button variant="primary">Add</.button>
              </.form>
            </div>

            <div>
              <h3 class="mb-2 font-medium">Link bank document</h3>
              <form :if={@linkable != []} phx-submit="link_material" class="flex items-end gap-2">
                <select name="document_id" class="select select-bordered select-sm">
                  <option :for={d <- @linkable} value={d.id}>{d.title}</option>
                </select>
                <button class="btn btn-sm btn-primary">Link</button>
              </form>
              <p :if={@linkable == []} class="text-sm opacity-70">
                No unlinked org documents.
              </p>
            </div>
          </div>
        </section>

        <div class="mt-6">
          <.link patch={~p"/courses"} class="btn btn-ghost">Back to courses</.link>
        </div>
      </div>

      <div :if={@live_action != :edit}>
        <.header>
          Courses
          <:subtitle>Course catalog.</:subtitle>
          <:actions>
            <.link
              :if={JosjobWeb.Perms.can?(@permissions, ["courses:create", "courses:manage"])}
              patch={~p"/courses/new"}
            >
              <.button variant="primary">New course</.button>
            </.link>
          </:actions>
        </.header>

        <.table id="courses" rows={@courses}>
          <:col :let={c} label="Title">{c.title}</:col>
          <:col :let={c} label="Section">{c.section && c.section.name}</:col>
          <:col :let={c} label="Active">{if c.is_active, do: "Yes", else: "No"}</:col>
          <:col :let={c} label="Industries">{Enum.map_join(c.industries, ", ", & &1.name)}</:col>
          <:col :let={c} label="Created">{JosjobWeb.Format.datetime(c.created_at)}</:col>
          <:col :let={c} label="Created by">{@audit_labels[c.created_by] || "-"}</:col>
          <:action :let={c}>
            <.link
              :if={JosjobWeb.Perms.can?(@permissions, ["courses:update", "courses:manage"])}
              patch={~p"/courses/#{c.id}/edit"}
              class="btn btn-ghost btn-xs"
            >
              Edit
            </.link>
          </:action>
          <:action :let={c}>
            <.link
              :if={JosjobWeb.Perms.can?(@permissions, ["courses:delete", "courses:manage"])}
              phx-click="delete"
              phx-value-id={c.id}
              data-confirm={"Delete course #{c.title}?"}
              class="btn btn-ghost btn-xs text-error"
            >
              Delete
            </.link>
          </:action>
        </.table>

        <div
          :if={@live_action == :new and @form != nil}
          id="course-modal"
          class="modal modal-open"
        >
          <div class="modal-box max-w-2xl">
            <h3 class="mb-4 text-lg font-bold">New course</h3>

            <.course_form
              form={@form}
              submit_label="Create"
              superuser={@permissions == :all}
              section_options={@section_options}
              industry_options={@industry_options}
              org_options={@org_options}
              industry_checked={@industry_checked}
              org_checked={@org_checked}
              cancel_patch={~p"/courses"}
            />
          </div>
          <.link patch={~p"/courses"} class="modal-backdrop" aria-label="Close"></.link>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
