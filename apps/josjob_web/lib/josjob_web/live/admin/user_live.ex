defmodule JosjobWeb.Admin.UserLive do
  @moduledoc """
  Menu admin Users versi LiveView (superuser only, pengganti ash_admin):
  list + search live (nama/email, state URL) + form modal + delete
  (bersihkan `user_identities` dulu — FK tanpa CASCADE).
  """
  use JosjobWeb, :live_view

  require Ash.Query

  alias Josjob.Accounts.{User, UserIdentity}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:q, q)
     |> load_users()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  defp apply_action(socket, :new, _params) do
    form = AshPhoenix.Form.for_create(User, :create, as: "user", authorize?: false)
    assign(socket, :form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = Ash.get!(User, id, authorize?: false)
    form = AshPhoenix.Form.for_update(user, :update, as: "user", authorize?: false)
    assign(socket, :form, to_form(form))
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: index_path(q))}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(AshPhoenix.Form.validate(socket.assigns.form.source, params)))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    verb = if socket.assigns.live_action == :new, do: "created", else: "updated"

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User #{to_string(user.email)} #{verb}.")
         |> push_patch(to: index_path(socket.assigns.q))}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = Ash.get!(User, id, authorize?: false)

    # `user_identities` punya FK ke `users` tanpa ON DELETE CASCADE -> hapus
    # identity OAuth-nya dulu agar destroy user tidak gagal.
    UserIdentity
    |> Ash.Query.filter(user_id == ^id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    Ash.destroy!(user, authorize?: false)

    {:noreply,
     socket
     |> put_flash(:info, "User #{to_string(user.email)} deleted.")
     |> load_users()}
  end

  # Query identik dengan UserController lama (ILIKE nama/email).
  defp load_users(socket) do
    users =
      User
      |> Ash.Query.sort(created_at: :desc)
      |> search(socket.assigns.q)
      |> Ash.read!(authorize?: false)

    assign(socket, :users, users)
  end

  defp search(query, ""), do: query

  defp search(query, q) do
    like = "%" <> q <> "%"

    Ash.Query.filter(
      query,
      fragment("? ILIKE ?", full_name, ^like) or fragment("?::text ILIKE ?", email, ^like)
    )
  end

  defp index_path(""), do: ~p"/users"
  defp index_path(q), do: ~p"/users?#{%{"q" => q}}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} active={:users} current_user={@current_user}>
      <.header>
        Users
        <:subtitle>Manage accounts (superuser only).</:subtitle>
        <:actions>
          <.link patch={~p"/users/new"}>
            <.button variant="primary">New user</.button>
          </.link>
        </:actions>
      </.header>

      <form id="user-filter" phx-change="filter" class="mb-4 flex flex-wrap items-center gap-2">
        <input
          type="text"
          name="q"
          value={@q}
          placeholder="Search name / email…"
          phx-debounce="300"
          class="input input-bordered input-sm w-full max-w-xs"
        />
        <.link :if={@q != ""} patch={~p"/users"} class="btn btn-sm btn-ghost">Reset</.link>
      </form>

      <.table id="users" rows={@users}>
        <:col :let={user} label="Name">{user.full_name}</:col>
        <:col :let={user} label="Email">{to_string(user.email)}</:col>
        <:col :let={user} label="Registration">{user.registration_type || "-"}</:col>
        <:col :let={user} label="Account type">
          {if user.account_type, do: to_string(user.account_type), else: "-"}
        </:col>
        <:col :let={user} label="Superuser">
          <span :if={user.is_superuser} class="badge badge-primary">superuser</span>
        </:col>
        <:col :let={user} label="Created">{JosjobWeb.Format.datetime(user.created_at)}</:col>
        <:col :let={user} label="Updated">{JosjobWeb.Format.datetime(user.updated_at)}</:col>
        <:action :let={user}>
          <.link patch={~p"/users/#{user.id}/edit"} class="btn btn-ghost btn-xs">Edit</.link>
        </:action>
        <:action :let={user}>
          <.link
            phx-click="delete"
            phx-value-id={user.id}
            data-confirm={"Delete user #{to_string(user.email)}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@live_action in [:new, :edit]} id="user-modal" class="modal modal-open">
        <div class="modal-box">
          <h3 class="mb-4 text-lg font-bold">
            {if @live_action == :new, do: "New user", else: "Edit user"}
          </h3>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:email]} type="email" label="Email" required />
            <.input field={@form[:full_name]} type="text" label="Full name" required />
            <.input field={@form[:phone]} type="text" label="Phone" />
            <.input field={@form[:address]} type="text" label="Address" />
            <.input field={@form[:birthdate]} type="date" label="Date of birth" />
            <.input field={@form[:is_superuser]} type="checkbox" label="Superuser (platform admin)" />
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
