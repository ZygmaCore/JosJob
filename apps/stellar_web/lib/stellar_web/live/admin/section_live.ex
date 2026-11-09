defmodule StellarWeb.Admin.SectionLive do
  @moduledoc """
  Menu admin Sections versi LiveView (pola pilot Skills): list + form modal
  (name/description/is_active) + delete (cabang error bila dipakai course).
  Tanpa search — mengikuti halaman lama.
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias StellarLrn.Learning.Section

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :audit_labels, StellarWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> load_sections()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    form =
      AshPhoenix.Form.for_create(Section, :create,
        as: "section",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    section = Ash.get!(Section, id, authorize?: false)

    form =
      AshPhoenix.Form.for_update(section, :update,
        as: "section",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  @impl true
  def handle_event("validate", %{"section" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"section" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, section} ->
        {:noreply,
         socket
         |> put_flash(:info, "Section #{section.name} #{verb}.")
         |> push_patch(to: ~p"/sections")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    section = Ash.get!(Section, id, authorize?: false)

    socket =
      case Ash.destroy(section, authorize?: false) do
        :ok ->
          put_flash(socket, :info, "Section #{section.name} deleted.")

        {:error, _} ->
          put_flash(socket, :error, "Failed to delete (may still be in use by a course).")
      end

    {:noreply, load_sections(socket)}
  end

  defp load_sections(socket) do
    sections = Section |> Ash.Query.sort(name: :asc) |> Ash.read!(authorize?: false)
    assign(socket, :sections, sections)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} active={:sections} current_user={@current_user}>
      <.header>
        Sections
        <:subtitle>Course category / department (global master data).</:subtitle>
        <:actions>
          <.link patch={~p"/sections/new"}>
            <.button variant="primary">New section</.button>
          </.link>
        </:actions>
      </.header>

      <.table id="sections" rows={@sections}>
        <:col :let={s} label="Name">{s.name}</:col>
        <:col :let={s} label="Description">{s.description}</:col>
        <:col :let={s} label="Active">{if s.is_active, do: "Yes", else: "No"}</:col>
        <:col :let={s} label="Created">{StellarWeb.Format.datetime(s.created_at)}</:col>
        <:col :let={s} label="Created by">{@audit_labels[s.created_by] || "-"}</:col>
        <:action :let={s}>
          <.link patch={~p"/sections/#{s.id}/edit"} class="btn btn-ghost btn-xs">Edit</.link>
        </:action>
        <:action :let={s}>
          <.link
            phx-click="delete"
            phx-value-id={s.id}
            data-confirm={"Delete section #{s.name}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@live_action in [:new, :edit]} id="section-modal" class="modal modal-open">
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New section", else: "Edit section"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:name]} type="text" label="Section name" required />
            <.input field={@form[:description]} type="textarea" label="Description" rows="3" />
            <.input field={@form[:is_active]} type="checkbox" label="Active" />
            <div class="modal-action justify-start">
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
              <.link patch={~p"/sections"} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
        </div>
        <.link patch={~p"/sections"} class="modal-backdrop" aria-label="Close"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
