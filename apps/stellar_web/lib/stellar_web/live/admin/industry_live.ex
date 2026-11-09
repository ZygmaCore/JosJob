defmodule StellarWeb.Admin.IndustryLive do
  @moduledoc """
  Menu admin Industries versi LiveView (pola pilot Skills): list + search live
  (state di URL) + form modal (parent select — exclude diri sendiri saat edit)
  + delete (dengan cabang error bila masih dipakai).
  """
  use StellarWeb, :live_view

  require Ash.Query

  alias Stellar.Orgs.Industry

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :audit_labels, StellarWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:q, q)
     |> load_industries()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params),
    do: socket |> assign(:form, nil) |> assign(:parent_options, [])

  defp apply_action(socket, :new, _params) do
    form =
      AshPhoenix.Form.for_create(Industry, :create,
        as: "industry",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    socket |> assign(:form, to_form(form)) |> assign(:parent_options, parent_options())
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    industry = Ash.get!(Industry, id, authorize?: false)

    form =
      AshPhoenix.Form.for_update(industry, :update,
        as: "industry",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    socket |> assign(:form, to_form(form)) |> assign(:parent_options, parent_options(id))
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: index_path(q))}
  end

  def handle_event("validate", %{"industry" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"industry" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: normalize(params)) do
      {:ok, industry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Industry #{industry.name} #{verb}.")
         |> push_patch(to: index_path(socket.assigns.q))}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    industry = Ash.get!(Industry, id, authorize?: false)

    socket =
      case Ash.destroy(industry, authorize?: false) do
        :ok -> put_flash(socket, :info, "Industry #{industry.name} deleted.")
        {:error, _} -> put_flash(socket, :error, "Failed to delete (may still be in use).")
      end

    {:noreply, load_industries(socket)}
  end

  # Query identik dengan IndustryController lama (ILIKE nama).
  defp load_industries(socket) do
    industries =
      Industry
      |> Ash.Query.sort(created_at: :desc)
      |> search(socket.assigns.q)
      |> Ash.read!(authorize?: false)

    socket
    |> assign(:industries, industries)
    |> assign(:parent_names, name_map())
  end

  defp search(query, ""), do: query

  defp search(query, q) do
    like = "%" <> q <> "%"
    Ash.Query.filter(query, fragment("? ILIKE ?", name, ^like))
  end

  # Opsi induk = industri lain (kecuali dirinya sendiri saat edit).
  defp parent_options(exclude_id \\ nil) do
    Industry
    |> Ash.read!(authorize?: false)
    |> Enum.reject(&(&1.id == exclude_id))
    |> Enum.sort_by(& &1.name)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp name_map do
    Industry |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end

  # parent_id "" (opsi "tanpa induk") -> nil.
  defp normalize(params) do
    if Map.get(params, "parent_id") in ["", nil],
      do: Map.put(params, "parent_id", nil),
      else: params
  end

  defp index_path(""), do: ~p"/industries"
  defp index_path(q), do: ~p"/industries?#{%{"q" => q}}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} active={:industries} current_user={@current_user}>
      <.header>
        Industries
        <:subtitle>Industry reference data for the organization.</:subtitle>
        <:actions>
          <.link patch={~p"/industries/new"}>
            <.button variant="primary">New industry</.button>
          </.link>
        </:actions>
      </.header>

      <form id="industry-filter" phx-change="filter" class="mb-4 flex flex-wrap items-center gap-2">
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="Search industry name…"
          phx-debounce="300"
          class="input input-bordered input-sm w-full max-w-xs"
        />
        <.link :if={@q != ""} patch={~p"/industries"} class="btn btn-sm btn-ghost">Reset</.link>
      </form>

      <.table id="industries" rows={@industries}>
        <:col :let={industry} label="Name">{industry.name}</:col>
        <:col :let={industry} label="Parent">{@parent_names[industry.parent_id] || "-"}</:col>
        <:col :let={industry} label="Created">
          {StellarWeb.Format.datetime(industry.created_at)}
        </:col>
        <:col :let={industry} label="Updated">
          {StellarWeb.Format.datetime(industry.updated_at)}
        </:col>
        <:col :let={industry} label="Created by">{@audit_labels[industry.created_by] || "-"}</:col>
        <:col :let={industry} label="Updated by">{@audit_labels[industry.updated_by] || "-"}</:col>
        <:action :let={industry}>
          <.link patch={~p"/industries/#{industry.id}/edit"} class="btn btn-ghost btn-xs">
            Edit
          </.link>
        </:action>
        <:action :let={industry}>
          <.link
            phx-click="delete"
            phx-value-id={industry.id}
            data-confirm={"Delete industry #{industry.name}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@live_action in [:new, :edit]} id="industry-modal" class="modal modal-open">
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New industry", else: "Edit industry"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:name]} type="text" label="Industry name" required />
            <.input
              field={@form[:parent_id]}
              type="select"
              label="Parent industry"
              options={@parent_options}
              prompt="— No parent —"
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
