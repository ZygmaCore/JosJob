# Skills LiveView Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrasi menu admin Skills dari controller klasik ke satu LiveView (list + search/filter live, form New/Edit di modal), plus hook auth `on_mount` reusable.

**Architecture:** `JosjobWeb.Admin.SkillLive` menangani tiga live_action (`:index/:new/:edit`) di dalam `ash_authentication_live_session :admin_live` dengan hook `JosjobWeb.LiveAuth :require_admin` (padanan plug RequireAdmin, juga menjaga reconnect websocket). Migrasi dua fase agar selalu shippable: fase 1 index live (new/edit masih controller), fase 2 modal + hapus controller lama.

**Tech Stack:** Phoenix LiveView (sudah ada, preseden RagLive), AshPhoenix.Form, daisyUI modal, Phoenix.LiveViewTest.

**Spec:** `docs/specs/2026-07-28-skills-liveview-pilot-design.md`

## Global Constraints

- **JANGAN menjalankan git sama sekali** — user yang pegang git; tidak ada langkah commit.
- Verifikasi dari repo root: `mix compile --warnings-as-errors`, `mix format --check-formatted`, `MIX_ENV=test mix test` harus bersih.
- Semua wording UI bahasa Inggris (konsisten sapuan i18n); komentar kode bahasa Indonesia.
- Flash error hook auth HARUS sama persis dengan plug RequireAdmin: `"You must be logged in as an administrator to access this page."`
- Email fixture test harus `@gmail.com`.
- Query list identik dengan controller lama: ILIKE nama + filter industry_id + sort `created_at: :desc`.

---

### Task 1: `LiveAuth` + `SkillLive` index (search/filter live), router hybrid

**Files:**
- Create: `apps/josjob_web/lib/josjob_web/live/live_auth.ex`
- Create: `apps/josjob_web/lib/josjob_web/live/admin/skill_live.ex`
- Modify: `apps/josjob_web/lib/josjob_web/router.ex` (scope superuser-only, baris `resources "/skills", SkillController, except: [:show]`)
- Test: `apps/josjob_web/test/josjob_web/live/admin/skill_live_test.exs` (baru)

**Interfaces:**
- Produces: `JosjobWeb.LiveAuth.on_mount(:require_admin, params, session, socket)`; route live `GET /skills` (live_action :index); `SkillLive` privates yang dipakai Task 2: `index_path(q, industry_id)`, `load_skills(socket)`, assigns `:skills, :q, :industry_id, :industry_options, :industry_names, :audit_labels`.
- Consumes: `Josjob.Authz.superuser?/1`; pola login test dari `class_controller_test.exs`.

- [ ] **Step 1: Tulis failing test**

`apps/josjob_web/test/josjob_web/live/admin/skill_live_test.exs`:

```elixir
defmodule JosjobWeb.Admin.SkillLiveTest do
  @moduledoc """
  Pilot LiveView Skills: gate superuser (LiveAuth), list + search/filter live
  dengan state di URL, form modal (Task 2), delete (Task 2).
  """
  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Orgs.{Industry, Skill}

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_industry(name) do
    Industry
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!(authorize?: false)
  end

  defp create_skill(name, industry \\ nil) do
    Skill
    |> Ash.Changeset.for_create(:create, %{name: name, industry_id: industry && industry.id})
    |> Ash.create!(authorize?: false)
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  setup %{conn: conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    {:ok, conn: login(conn, superuser)}
  end

  test "non-superuser di-redirect ke / dengan flash error", %{conn: _} do
    biasa = create_user("biasa@gmail.com", "User Biasa")
    conn = login(Phoenix.ConnTest.build_conn(), biasa)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/skills")
  end

  test "list tampil; search & filter industri menyaring + menulis URL", %{conn: conn} do
    las = create_industry("Las")
    create_skill("Welding Dasar", las)
    create_skill("Housekeeping")

    {:ok, view, html} = live(conn, ~p"/skills")
    assert html =~ "Welding Dasar"
    assert html =~ "Housekeeping"

    # search live: menyaring + patch URL
    view |> element("#skill-filter") |> render_change(%{"q" => "Weld", "industry_id" => ""})
    assert_patch(view, ~p"/skills?q=Weld")
    html = render(view)
    assert html =~ "Welding Dasar"
    refute html =~ "Housekeeping"

    # filter industri live
    view |> element("#skill-filter") |> render_change(%{"q" => "", "industry_id" => las.id})
    assert_patch(view, ~p"/skills?industry_id=#{las.id}")
    html = render(view)
    assert html =~ "Welding Dasar"
    refute html =~ "Housekeeping"
  end

  test "buka /skills dengan query param langsung tersaring", %{conn: conn} do
    create_skill("Welding Dasar")
    create_skill("Housekeeping")

    {:ok, _view, html} = live(conn, ~p"/skills?q=House")
    assert html =~ "Housekeeping"
    refute html =~ "Welding Dasar"
  end
end
```

- [ ] **Step 2: Jalankan — harus GAGAL**

Run: `MIX_ENV=test mix test apps/josjob_web/test/josjob_web/live/admin/skill_live_test.exs`
Expected: FAIL — `no route found for GET /skills` versi live (`live/3` belum ada; error berbentuk redirect/route mismatch).

- [ ] **Step 3: Buat `JosjobWeb.LiveAuth`**

`apps/josjob_web/lib/josjob_web/live/live_auth.ex`:

```elixir
defmodule JosjobWeb.LiveAuth do
  @moduledoc """
  Hook `on_mount` untuk LiveView admin. `:require_admin` = superuser only —
  padanan plug `JosjobWeb.Plugs.RequireAdmin` (wording flash sama persis).
  Hook wajib walau route sudah ber-pipeline require_admin: plug hanya menjaga
  mount HTTP pertama; hook juga menjaga reconnect websocket.
  """
  import Phoenix.LiveView

  def on_mount(:require_admin, _params, _session, socket) do
    if Josjob.Authz.superuser?(socket.assigns[:current_user]) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be logged in as an administrator to access this page.")
       |> redirect(to: "/")}
    end
  end
end
```

- [ ] **Step 4: Buat `SkillLive` (index saja)**

`apps/josjob_web/lib/josjob_web/live/admin/skill_live.ex`:

```elixir
defmodule JosjobWeb.Admin.SkillLive do
  @moduledoc """
  Pilot LiveView: menu admin Skills — list + search/filter live (state di URL).
  Spec: docs/specs/2026-07-28-skills-liveview-pilot-design.md. Task 2 menambah
  form modal New/Edit + delete.
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
     |> load_skills()}
  end

  @impl true
  def handle_event("filter", %{"q" => q, "industry_id" => industry_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(q, industry_id))}
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
    params =
      %{"q" => q, "industry_id" => industry_id}
      |> Enum.reject(fn {_k, v} -> v in ["", nil] end)
      |> Map.new()

    if params == %{}, do: ~p"/skills", else: ~p"/skills?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} active={:skills} current_user={@current_user}>
      <.header>
        Skills
        <:subtitle>Skill master data (linked to industry).</:subtitle>
        <:actions>
          <.link navigate={~p"/skills/new"}>
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
          <.link navigate={~p"/skills/#{s.id}/edit"} class="btn btn-ghost btn-xs">Edit</.link>
        </:action>
        <:action :let={s}>
          <.link
            href={~p"/skills/#{s.id}"}
            method="delete"
            data-confirm={"Delete skill #{s.name}?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.admin>
    """
  end
end
```

CATATAN: tombol New/Edit/Delete masih `navigate`/`href` ke route controller —
hybrid yang disengaja; Task 2 menggantinya dengan modal + event.

- [ ] **Step 5: Router — hybrid**

Di scope superuser-only (`pipe_through [:browser, :require_admin]`), ganti
`resources "/skills", SkillController, except: [:show]` dengan:

```elixir
    resources "/skills", SkillController, only: [:new, :create, :edit, :update, :delete]

    ash_authentication_live_session :admin_live,
      on_mount: [{JosjobWeb.LiveAuth, :require_admin}] do
      live "/skills", Admin.SkillLive, :index
    end
```

(Scope-nya `scope "/", JosjobWeb.Admin` — maka modul live dirujuk sebagai
`Admin.SkillLive`? TIDAK: scope admin memakai alias `JosjobWeb.Admin`, dan
modul kita `JosjobWeb.Admin.SkillLive`, jadi cukup `SkillLive`. Cek alias
scope aktual saat mengedit.)

- [ ] **Step 6: Jalankan — harus HIJAU**

Run: `MIX_ENV=test mix test apps/josjob_web/test/josjob_web/live/admin/skill_live_test.exs`
Expected: PASS 3 test.

- [ ] **Step 7: Verifikasi gerbang**

Run: `mix compile --warnings-as-errors && mix format --check-formatted && MIX_ENV=test mix test`
Expected: semua bersih (controller lama masih dipakai route non-index — tidak ada warning unused).

---

### Task 2: Modal New/Edit + delete event; hapus controller lama

**Files:**
- Modify: `apps/josjob_web/lib/josjob_web/live/admin/skill_live.ex`
- Modify: `apps/josjob_web/lib/josjob_web/router.ex` (swap sisa route)
- Delete: `apps/josjob_web/lib/josjob_web/controllers/admin/skill_controller.ex`, `skill_html.ex`, `skill_html/` (3 template)
- Test: `skill_live_test.exs` (tambah 4 test)

**Interfaces:**
- Consumes: `index_path/2`, `load_skills/1`, assigns Task 1.
- Produces: live_action `:new`/`:edit`, event `validate`/`save`/`delete` — terminal.

- [ ] **Step 1: Tambah failing tests**

```elixir
  test "modal new: submit valid membuat skill; invalid menampilkan error", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/skills/new")
    assert has_element?(view, "#skill-modal")

    # invalid: nama kosong -> error tampil, modal tetap
    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "", "industry_id" => ""}})

    assert has_element?(view, "#skill-modal")
    assert render(view) =~ "is required"

    # valid -> patch ke index, skill tampil + flash
    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "Welding Lanjut", "industry_id" => ""}})

    assert_patch(view, ~p"/skills")
    html = render(view)
    assert html =~ "Welding Lanjut"
    assert html =~ "created"
  end

  test "modal edit: mengubah nama", %{conn: conn} do
    skill = create_skill("Nama Lama")

    {:ok, view, _} = live(conn, ~p"/skills/#{skill.id}/edit")
    assert has_element?(view, "#skill-modal")

    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "Nama Baru", "industry_id" => ""}})

    assert_patch(view, ~p"/skills")
    html = render(view)
    assert html =~ "Nama Baru"
    refute html =~ "Nama Lama"
  end

  test "delete menghapus dari list", %{conn: conn} do
    skill = create_skill("Akan Dihapus")

    {:ok, view, html} = live(conn, ~p"/skills")
    assert html =~ "Akan Dihapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{skill.id}"]}) |> render_click()

    html = render(view)
    refute html =~ "Akan Dihapus"
    assert html =~ "deleted"
  end

  test "filter terjaga setelah save dari modal", %{conn: conn} do
    create_skill("Welding Dasar")

    {:ok, view, _} = live(conn, ~p"/skills?q=Weld")
    view |> element("a", "New skill") |> render_click()
    assert_patch(view, ~p"/skills/new?q=Weld")

    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "Welding Lanjut", "industry_id" => ""}})

    assert_patch(view, ~p"/skills?q=Weld")
    html = render(view)
    assert html =~ "Welding Lanjut"
  end
```

- [ ] **Step 2: Jalankan — harus GAGAL**

Run: `MIX_ENV=test mix test apps/josjob_web/test/josjob_web/live/admin/skill_live_test.exs`
Expected: FAIL — route live `/skills/new` belum ada.

- [ ] **Step 3: Router — swap penuh**

Hapus baris `resources "/skills", SkillController, only: [...]`; lengkapi live session:

```elixir
    ash_authentication_live_session :admin_live,
      on_mount: [{JosjobWeb.LiveAuth, :require_admin}] do
      live "/skills", SkillLive, :index
      live "/skills/new", SkillLive, :new
      live "/skills/:id/edit", SkillLive, :edit
    end
```

- [ ] **Step 4: SkillLive — live_action, form, modal, delete**

Tambahkan/ubah di `skill_live.ex`:

`handle_params` menjadi (apply_action per live_action):

```elixir
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
```

Events (tambah di bawah `handle_event("filter", ...)`):

```elixir
  @impl true
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
```

Render — ganti tombol New/Edit/Delete + tambah modal sebelum `</Layouts.admin>`:

- Tombol New: `<.link patch={~p"/skills/new?#{filter_params(@q, @industry_id)}"}>` — TAPI
  sederhanakan: pakai helper `action_path(:new, @q, @industry_id)`; lihat kode di bawah.
- Aksi baris Edit: `<.link patch={action_path({:edit, s.id}, @q, @industry_id)} class="btn btn-ghost btn-xs">Edit</.link>`
- Aksi baris Delete:

```heex
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
```

- Modal (sebelum `</Layouts.admin>`):

```heex
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
        <.link patch={index_path(@q, @industry_id)} class="modal-backdrop" aria-label="Close">
        </.link>
      </div>
```

- Helper path aksi (filter terjaga saat membuka modal):

```elixir
  # Path new/edit dengan filter terjaga (q/industry_id ikut sebagai query).
  defp action_path(action, q, industry_id) do
    params =
      %{"q" => q, "industry_id" => industry_id}
      |> Enum.reject(fn {_k, v} -> v in ["", nil] end)
      |> Map.new()

    case {action, params} do
      {:new, p} when p == %{} -> ~p"/skills/new"
      {:new, p} -> ~p"/skills/new?#{p}"
      {{:edit, id}, p} when p == %{} -> ~p"/skills/#{id}/edit"
      {{:edit, id}, p} -> ~p"/skills/#{id}/edit?#{p}"
    end
  end
```

  Tombol New memakai `patch={action_path(:new, @q, @industry_id)}`.

- [ ] **Step 5: Hapus file controller lama**

Hapus: `apps/josjob_web/lib/josjob_web/controllers/admin/skill_controller.ex`,
`.../admin/skill_html.ex`, direktori `.../admin/skill_html/`.
Lalu: `grep -rn "SkillController\|SkillHTML" apps/` harus nol (router sudah bersih).

- [ ] **Step 6: Jalankan — harus HIJAU**

Run: `MIX_ENV=test mix test apps/josjob_web/test/josjob_web/live/admin/skill_live_test.exs`
Expected: PASS 7 test.

---

### Task 3: Gerbang akhir

- [ ] **Step 1:** `mix compile --warnings-as-errors && mix format --check-formatted && MIX_ENV=test mix test` — semua bersih.
- [ ] **Step 2:** `grep -rn "SkillController\|skill_html" apps/josjob_web/lib` — nol referensi tersisa.
