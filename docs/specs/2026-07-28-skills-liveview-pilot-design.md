# Spec: Pilot LiveView — halaman admin Skills

Tanggal: 2026-07-28
Status: disetujui (brainstorm 2026-07-28)

## Latar belakang & tujuan

Panel admin saat ini controller klasik + HEEx (full reload per aksi); satu-satunya
LiveView adalah `/rag`. Interaktivitas dalam-halaman harus ditulis sebagai JS
vanilla manual (contoh: dropdown pengajar dinamis di form class). Pilot ini
memigrasikan SATU menu — **Skills**, CRUD terkecil (superuser-only) — untuk:

1. Membuktikan pola migrasi (routing, auth hook, form Ash, testing LiveView).
2. Menghasilkan fondasi reusable (`on_mount` auth hook) untuk migrasi menu lain.

Bukan tujuan pilot: memigrasikan menu lain, pagination/sorting/streams.

## Kondisi sekarang (yang diganti)

- `StellarWeb.Admin.SkillController` (index dengan search `q` + filter
  `industry_id` via query param, new, create, edit, update, delete).
- `StellarWeb.Admin.SkillHTML` + 3 template (index/new/edit).
- Route `resources "/skills", SkillController, except: [:show]` di scope
  superuser-only (`pipe_through [:browser, :require_admin]`).
- Belum ada test untuk skills.

## Desain

### Bentuk UI: satu halaman + modal

Satu LiveView `StellarWeb.Admin.SkillLive` (lib/stellar_web/live/admin/skill_live.ex):

- `/skills` (live_action `:index`) — tabel skills (kolom sama seperti sekarang,
  termasuk audit "Created/Updated (by)") + search + filter industri, semuanya live.
- `/skills/new` (`:new`) dan `/skills/:id/edit` (`:edit`) — form di MODAL
  (daisyUI, dikontrol live_action) di atas list; tutup modal = `push_patch`
  kembali ke `/skills` dengan filter terjaga.
- Delete: tombol di baris, `phx-click="delete"` + `phx-value-id` + `data-confirm`
  ("Delete skill NAMA?"), list ter-update tanpa reload.

### Routing & auth

- Ganti route resources dengan tiga route live, tetap di scope superuser-only
  yang sama (pipeline `[:browser, :require_admin]` — plug hanya menjaga mount
  HTTP pertama), dibungkus `ash_authentication_live_session :admin_live`
  dengan hook on_mount (menjaga JUGA reconnect websocket — karenanya wajib):

  ```elixir
  live "/skills", SkillLive, :index
  live "/skills/new", SkillLive, :new
  live "/skills/:id/edit", SkillLive, :edit
  ```

- **Hook baru `StellarWeb.LiveAuth`** (lib/stellar_web/live/live_auth.ex),
  `on_mount(:require_admin)`: pakai `Stellar.Authz.superuser?/1` (otoritatif
  DB — perilaku sama dengan plug `RequireAdmin`); bukan superuser → `{:halt,
  redirect(socket, to: "/")}` + flash error dengan wording yang SAMA dengan
  plug ("You must be logged in as an administrator to access this page.").
  Hook ini fondasi reusable untuk migrasi menu admin berikutnya.
- Layout: render `<Layouts.admin flash={@flash} current_user={@current_user}
  active={:skills}>` — pola minimal yang sama dengan RagLive (superuser
  melihat menu lengkap lewat bypass `nav_for`).

### Data & interaksi

- `handle_params`: baca `q` dan `industry_id` dari URL, jalankan query yang
  SAMA dengan controller lama (ILIKE nama + filter industry_id, sort
  `created_at: :desc`), assign list.
- Search: input `phx-change` + `phx-debounce="300"`; filter industri: select
  `phx-change` langsung. Keduanya `push_patch` ke `/skills?q=...&industry_id=...`
  → state filter selalu di URL (shareable/refresh-safe). Nilai kosong tidak
  ditulis ke URL.
- Form modal: `AshPhoenix.Form.for_create/for_update` (as: "skill",
  authorize?: false, actor: current_user) — logika `normalize` (industry_id
  "" → nil) dipertahankan. `phx-change="validate"` untuk validasi live,
  `phx-submit="save"`. Sukses → `put_flash` ("Skill NAMA created/updated.") +
  `push_patch` ke `/skills` (filter terjaga); error → form dirender ulang di
  modal dengan pesan error.
- Delete sukses → flash "Skill NAMA deleted." + list dimuat ulang.
- Industri: `industry_options` + `industry_name_map` dibaca sekali di mount.

### Yang dihapus

`SkillController`, `SkillHTML`, `skill_html/` (3 template), route resources
lama. Item nav `:skills` tidak berubah (path tetap `/skills`).

## Testing (Phoenix.LiveViewTest — semuanya baru)

1. Non-superuser (atau tanpa login) mengakses `/skills` → redirect `/`.
2. Superuser: list tampil; ketik search menyaring; ganti filter industri
   menyaring; `q`/`industry_id` muncul di URL (assert_patch).
3. Buka `/skills/new` → modal tampil → submit valid → skill muncul di list +
   flash; submit invalid (nama kosong) → error tampil di modal, tetap terbuka.
4. `/skills/:id/edit` → ubah nama → tersimpan + tampil di list.
5. Delete → hilang dari list + flash.
6. Filter terjaga setelah save (push_patch membawa q/industry_id… minimal:
   setelah save kembali ke index tanpa error).

## Kriteria selesai

- `mix compile --warnings-as-errors`, `mix format --check-formatted`,
  `MIX_ENV=test mix test` bersih.
- Menu Skills berfungsi penuh sebagai LiveView (CRUD + search/filter live).
- Controller & template lama terhapus; tidak ada route ganda `/skills`.
- `StellarWeb.LiveAuth.on_mount(:require_admin)` siap dipakai menu lain.
