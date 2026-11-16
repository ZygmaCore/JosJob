defmodule JosjobWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use JosjobWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1"></div>
      <div class="flex-none">
        <ul class="flex items-center gap-2 px-1">
          <li>
            <.theme_toggle />
          </li>
          <li>
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-ghost btn-circle" aria-label="User menu">
                <.icon name="hero-user-circle" class="size-6" />
              </div>
              <ul
                tabindex="0"
                class="menu dropdown-content z-10 mt-3 w-44 rounded-box bg-base-100 p-2 shadow"
              >
                <li>
                  <a href={~p"/sign-out"}>
                    <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Logout
                  </a>
                </li>
              </ul>
            </div>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Layout panel admin: sidebar kiri (navigasi) + top bar (tema + menu user).

  Item menu didefinisikan terpusat di `admin_nav/0` — tambah menu baru cukup
  menambah satu entri di sana. `active` menandai item yang sedang aktif.

      <Layouts.admin flash={@flash} active={:users}>...</Layouts.admin>
  """
  attr :flash, :map, required: true
  attr :active, :atom, default: nil, doc: "key item nav yang aktif"
  attr :current_user, :map, default: nil, doc: "user login (untuk filter menu per-role)"
  attr :permissions, :any, default: nil, doc: ":all (superuser) atau MapSet izin efektif"
  attr :active_organization_id, :string, default: nil, doc: "org aktif (untuk switcher)"
  attr :member_orgs, :list, default: [], doc: "list %{id, name} org member (untuk switcher)"
  slot :inner_block, required: true

  def admin(assigns) do
    assigns = assign(assigns, :nav, nav_for(assigns[:current_user], assigns[:permissions]))

    ~H"""
    <div class="flex min-h-screen bg-base-100">
      <aside class="flex w-60 shrink-0 flex-col border-r border-base-300 bg-base-200">
        <div class="flex h-16 items-center gap-2 border-b border-base-300 px-4 text-lg font-bold">
          <.icon name="hero-squares-2x2" class="size-5 text-primary" /> JosJob Admin
        </div>
        <nav class="flex-1 overflow-y-auto p-2">
          <ul class="menu w-full gap-1">
            <li :for={item <- @nav}>
              <a href={item.path} class={@active == item.key && "menu-active"}>
                <.icon name={item.icon} class="size-4" />
                {item.label}
              </a>
            </li>
          </ul>
        </nav>
      </aside>

      <div class="flex min-w-0 flex-1 flex-col">
        <header class="navbar border-b border-base-300 px-4 sm:px-6">
          <div class="flex-1"></div>
          <div class="flex-none">
            <ul class="flex items-center gap-2 px-1">
              <li :if={length(@member_orgs) >= 2}>
                <div class="dropdown dropdown-end">
                  <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1">
                    <.icon name="hero-building-office" class="size-4" />
                    {active_org_name(@member_orgs, @active_organization_id)}
                    <.icon name="hero-chevron-down" class="size-3" />
                  </div>
                  <ul
                    tabindex="0"
                    class="menu dropdown-content z-10 mt-3 w-56 rounded-box bg-base-100 p-2 shadow"
                  >
                    <li class="menu-title">Switch organization</li>
                    <li :for={o <- @member_orgs}>
                      <.form for={%{}} action={~p"/switch-org"} method="post" class="p-0">
                        <input type="hidden" name="organization_id" value={o.id} />
                        <button
                          type="submit"
                          class={[
                            "w-full text-left",
                            @active_organization_id == o.id && "menu-active"
                          ]}
                        >
                          {o.name}
                        </button>
                      </.form>
                    </li>
                  </ul>
                </div>
              </li>
              <li>
                <.theme_toggle />
              </li>
              <li>
                <div class="dropdown dropdown-end">
                  <div
                    tabindex="0"
                    role="button"
                    class="btn btn-ghost btn-circle"
                    aria-label="User menu"
                  >
                    <.icon name="hero-user-circle" class="size-6" />
                  </div>
                  <ul
                    tabindex="0"
                    class="menu dropdown-content z-10 mt-3 w-44 rounded-box bg-base-100 p-2 shadow"
                  >
                    <li>
                      <a href={~p"/sign-out"}>
                        <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Logout
                      </a>
                    </li>
                  </ul>
                </div>
              </li>
            </ul>
          </div>
        </header>

        <main class="flex-1 p-4 sm:p-6 lg:p-8">
          <div class="mx-auto max-w-5xl space-y-4">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  # Menu sidebar (sumber tunggal). `visible: :any` = semua member; `:superuser` =
  # hanya superuser platform. Tambah menu baru = tambah satu entri.
  defp admin_nav do
    [
      %{
        key: :dashboard,
        label: "Dashboard",
        path: "/dashboard",
        icon: "hero-chart-pie",
        visible: :any
      },
      %{
        key: :rag,
        label: "RAG Documents",
        path: "/rag",
        icon: "hero-document-text"
      },
      %{
        key: :my_documents,
        label: "My Documents",
        path: "/my/documents",
        icon: "hero-document",
        visible: :any
      },
      %{key: :users, label: "Users", path: "/users", icon: "hero-users", visible: :superuser},
      %{
        key: :documents,
        label: "Documents",
        path: "/documents",
        icon: "hero-document-text",
        permission: "documents:manage"
      },
      %{
        key: :organizations,
        label: "Organizations",
        path: "/organizations",
        icon: "hero-building-office",
        permission: "organizations:read"
      },
      %{
        key: :memberships,
        label: "Memberships",
        path: "/memberships",
        icon: "hero-identification",
        permission: ["members:read", "members:manage"]
      },
      %{
        key: :membership_roles,
        label: "Membership Roles",
        path: "/membership-roles",
        icon: "hero-user-group",
        permission: ["members:read", "members:manage"]
      },
      %{
        key: :industries,
        label: "Industries",
        path: "/industries",
        icon: "hero-building-office-2",
        visible: :superuser
      },
      %{
        key: :sections,
        label: "Sections",
        path: "/sections",
        icon: "hero-rectangle-stack",
        visible: :superuser
      },
      %{
        key: :courses,
        label: "Courses",
        path: "/courses",
        icon: "hero-academic-cap",
        permission: course_perms()
      },
      %{
        key: :classes,
        label: "Classes",
        path: "/classes",
        icon: "hero-user-group",
        permission: class_perms()
      },
      %{
        key: :teachers,
        label: "Teachers",
        path: "/teachers",
        icon: "hero-user",
        permission: ["teachers:read", "teachers:manage"]
      },
      %{
        key: :enrollments,
        label: "Enrollments",
        path: "/enrollments",
        icon: "hero-clipboard-document-check",
        permission: enroll_perms()
      },
      %{
        key: :skills,
        label: "Skills",
        path: "/skills",
        icon: "hero-sparkles",
        visible: :superuser
      },
      %{
        key: :roles,
        label: "Roles",
        path: "/roles",
        icon: "hero-shield-check",
        visible: :superuser
      },
      %{
        key: :permissions,
        label: "Permissions",
        path: "/permissions",
        icon: "hero-key",
        visible: :superuser
      }
    ]
  end

  # Permission apa pun yang memberi akses ke area course (`manage` = superset).
  defp course_perms,
    do: ["courses:read", "courses:create", "courses:update", "courses:delete", "courses:manage"]

  # Permission apa pun yang memberi akses ke area class (class/enrollment).
  defp class_perms,
    do: [
      "classes:read",
      "classes:create",
      "classes:update",
      "classes:delete",
      "classes:manage",
      "enrollments:read",
      "enrollments:create",
      "enrollments:update",
      "enrollments:delete",
      "enrollments:manage"
    ]

  # Permission apa pun yang memberi akses ke area enrollment.
  defp enroll_perms,
    do: [
      "enrollments:read",
      "enrollments:create",
      "enrollments:update",
      "enrollments:delete",
      "enrollments:manage"
    ]

  # Nama org aktif untuk label switcher (fallback ke org pertama).
  defp active_org_name(member_orgs, active_id) do
    case Enum.find(member_orgs, &(&1.id == active_id)) do
      %{name: name} ->
        name

      _ ->
        case member_orgs do
          [%{name: name} | _] -> name
          _ -> "Organization"
        end
    end
  end

  defp nav_for(user, permissions) do
    superuser? = match?(%{is_superuser: true}, user)

    Enum.filter(admin_nav(), fn item ->
      cond do
        perm = item[:permission] -> superuser? or JosjobWeb.Perms.can?(permissions, perm)
        item[:visible] == :any -> true
        item[:visible] == :superuser -> superuser?
        true -> false
      end
    end)
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
