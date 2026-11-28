defmodule JosjobWeb.Admin.SkillLive do
  @moduledoc """
  Pilot LiveView: menu admin Skills — list + search/filter live (state di URL).
  Spec: docs/specs/2026-07-28-skills-liveview-pilot-design.md. Form New/Edit di
  modal + delete menyusul (Task 2 plan).
  """
  use JosjobWeb, :live_view

  require Ash.Query

  alias Josjob.Orgs.{Industry, Skill}

  @impl true
  def mount(_params, _session, socket) do
    industries = Industry |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.name)

    {:ok,
     socket
     |> assign(:industry_options, Enum.map(industries, &{&1.name, &1.id}))
     |> assign(:industry_names, Map.new(industries, &{&1.id, &1.name}))
     |> assign(:audit_labels, JosjobWeb.Audit.user_labels())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()
    industry_id = params |> Map.get("industry_id", "") |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:q, q)
     |> assign(:industry_id, industry_id)
     |> load_skills()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    form =
      AshPhoenix.Form.for_create(Skill, :create,
        as: "skill",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    skill = Ash.get!(Skill, id, authorize?: false)

    form =
      AshPhoenix.Form.for_update(skill, :update,
        as: "skill",
        authorize?: false,
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  @impl true
  def handle_event("filter", %{"q" => q, "industry_id" => industry_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(q, industry_id))}
  end

  def handle_event("validate", %{"skill" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"skill" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: normalize(params)) do
      {:ok, skill} ->
        {:noreply,
         socket
         |> put_flash(:info, "Skill #{skill.name} #{verb}.")
         |> push_patch(to: index_path(socket.assigns.q, socket.assigns.industry_id))}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    skill = Ash.get!(Skill, id, authorize?: false)
    Ash.destroy!(skill, authorize?: false)

    {:noreply,
     socket
     |> put_flash(:info, "Skill #{skill.name} deleted.")
     |> load_skills()}
  end

  # industry_id "" (opsi kosong) -> nil, sama seperti controller lama.
  defp normalize(params) do
    if Map.get(params, "industry_id") in ["", nil],
      do: Map.put(params, "industry_id", nil),
      else: params
  end

  # Query identik dengan SkillController lama (ILIKE nama + filter industri).
  defp load_skills(socket) do
    %{q: q, industry_id: industry_id} = socket.assigns

    skills =
      Skill
      |> Ash.Query.sort(created_at: :desc)
      |> search(q)
      |> filter_industry(industry_id)
      |> Ash.read!(authorize?: false)

    assign(socket, :skills, skills)
  end

  defp search(query, ""), do: query

  defp search(query, q) do
    like = "%" <> q <> "%"
    Ash.Query.filter(query, fragment("? ILIKE ?", name, ^like))
  end

  defp filter_industry(query, ""), do: query
  defp filter_industry(query, id), do: Ash.Query.filter(query, industry_id == ^id)

  # Path index dengan filter terjaga; param kosong tidak ditulis ke URL.
  defp index_path(q, industry_id) do
    case filter_params(q, industry_id) do
      p when p == %{} -> ~p"/skills"
      p -> ~p"/skills?#{p}"
    end
  end

  # Path new/edit dengan filter terjaga (q/industry_id ikut sebagai query).
  defp action_path(action, q, industry_id) do
    case {action, filter_params(q, industry_id)} do
      {:new, p} when p == %{} -> ~p"/skills/new"
      {:new, p} -> ~p"/skills/new?#{p}"
      {{:edit, id}, p} when p == %{} -> ~p"/skills/#{id}/edit"
      {{:edit, id}, p} -> ~p"/skills/#{id}/edit?#{p}"
    end
  end

  defp filter_params(q, industry_id) do
    %{"q" => q, "industry_id" => industry_id}
    |> Enum.reject(fn {_k, v} -> v in ["", nil] end)
    |> Map.new()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} active={:skills} current_user={@current_user}>
      <.header>
        Skills
        <:subtitle>Skill master data (linked to industry).</:subtitle>
        <:actions>
          <.link patch={action_path(:new, @q, @industry_id)}>
            <.button variant="primary">New skill</.button>
          </.link>
        </:actions>
      </.header>

      <form id="skill-filter" phx-change="filter" class="mb-4 flex flex-wrap items-center gap-2">
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="Search skill name…"
          phx-debounce="300"
          class="input input-bordered input-sm w-full max-w-xs"
        />
        <select name="industry_id" class="select select-bordered select-sm">
          <option value="">All industries</option>
          <option :for={{label, id} <- @industry_options} value={id} selected={@industry_id == id}>
            {label}
          </option>
        </select>
        <.link :if={@q != "" or @industry_id != ""} patch={~p"/skills"} class="btn btn-sm btn-ghost">
          Reset
        </.link>
      </form>

      <.table id="skills" rows={@skills}>
        <:col :let={s} label="Name">{s.name}</:col>
        <:col :let={s} label="Industry">{@industry_names[s.industry_id] || "-"}</:col>
        <:col :let={s} label="Created">{JosjobWeb.Format.datetime(s.created_at)}</:col>
        <:col :let={s} label="Updated">{JosjobWeb.Format.datetime(s.updated_at)}</:col>
        <:col :let={s} label="Created by">{@audit_labels[s.created_by] || "-"}</:col>
        <:col :let={s} label="Updated by">{@audit_labels[s.updated_by] || "-"}</:col>
        <:action :let={s}>
          <.link patch={action_path({:edit, s.id}, @q, @industry_id)} class="btn btn-ghost btn-xs">
            Edit
          </.link>
        </:action>
        <:action :let={s}>
          <.link
            phx-click="delete"
            phx-value-id={s.id}
            data-confirm={"Delete skill #{s.name}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@live_action in [:new, :edit]} id="skill-modal" class="modal modal-open">
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New skill", else: "Edit skill"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input
              field={@form[:industry_id]}
              type="select"
              label="Industry"
              options={@industry_options}
              prompt="— Select industry —"
            />
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
