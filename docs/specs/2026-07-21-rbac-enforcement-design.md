# Spec — RBAC Enforcement (Iterasi Engine, Web-layer)

**Tanggal:** 2026-07-21
**Status:** Disepakati untuk diimplementasi (menunggu review spec)
**Konteks:** JosJob (Elixir umbrella, Ash + AshPostgres, Phoenix). Multi-tenant. Data RBAC (permissions, roles, role_permissions, memberships, membership_roles) sudah ada tapi **belum ditegakkan** — gating saat ini hanya `is_superuser` + keanggotaan.

---

## 1. Ringkasan

Membangun **engine RBAC** di lapisan web (helper + plug) yang menghitung **izin efektif** user pada **organisasi aktif**, lalu menerapkannya ke **menu**, **akses route**, **aksi (read vs manage)**, dan **scoping data per-tenant**. Enforcement lewat `Josjob.Authz` + plug — **bukan** Ash policy (resource tetap `authorize?: false`). Ash policy menyusul selektif di iterasi lain.

Diterapkan sebagai bukti ke **2 surface per-org** yang sudah ada: **Memberships** & **Organizations**. Master data global (users/industries/skills/roles/permissions/documents) tetap superuser-only.

## 2. Keputusan Kunci

| Topik | Keputusan |
|---|---|
| Lingkup | **Engine dulu** + terapkan minimal (bukti) ke Memberships & Organizations. |
| Org aktif | Disimpan di **session**; default = membership aktif pertama; **switcher UI ditunda**. |
| Mekanisme | **Web-layer** (`Josjob.Authz` + plug + menu helper). Resource Ash tetap `authorize?: false`. |
| Izin efektif | Union `role_permissions` dari `membership_roles` pada org aktif. **Tidak** digabung lintas-org. |
| Superuser | **Bypass** semua (lihat semua, semua aksi). |
| Scoping data | **Ikut** — non-superuser hanya melihat data org aktifnya di surface bukti. |

## 3. Engine — `Josjob.Authz` (app `:josjob`)

Tambahan fungsi:

- `permissions_for(user, org_id)` → `MapSet.t(String.t())`
  Query: `memberships` (user_id, organization_id=org_id, status `:active`) → `membership_roles` → role_ids → `role_permissions` → permission_ids → `permissions.key`. Union ke MapSet. Tanpa membership aktif → `MapSet.new()`.
- `can?(user, org_id, permission)` → `boolean`
  `superuser?(user)` → `true`; selain itu `MapSet.member?(permissions_for(user, org_id), permission)`.
- `active_org_id(session_value, user)` → `uuid | nil`
  Pakai `session_value` bila user memang punya membership aktif di org itu; jika tidak, default = organisasi dari membership aktif pertama; `nil` bila tak ada.

Catatan: superuser tidak melewati `permissions_for` (di-bypass di `can?`). Fungsi murni-baca (`authorize?: false`).

## 4. Plumbing Web (`josjob_web`)

- **Plug `JosjobWeb.Plugs.AssignActiveOrg`** — dipasang di pipeline `:browser` setelah `load_josjob_user`. Bila ada `current_user`, set:
  - `conn.assigns.active_organization_id` = `Josjob.Authz.active_org_id(get_session(conn, "active_organization_id"), current_user)`
  - `conn.assigns.permissions` = `MapSet` izin efektif (`permissions_for`), atau `:all` bila superuser.
  Dihitung sekali per request. Bila tak ada user → assign default (nil / MapSet kosong).
- **Plug `JosjobWeb.Plugs.RequirePermission`** — `init` menerima permission string. Lolos bila `can?(current_user, active_organization_id, perm)`; jika tidak → flash + redirect ke `/` (atau 403). Superuser selalu lolos.
- **Menu** (`Layouts.admin_nav/0` + `nav_for/2`): tiap item boleh punya `permission:`. Aturan tampil:
  - `visible: :any` → selalu (untuk user login; mis. Dashboard, Dokumen Saya).
  - `visible: :superuser` → hanya superuser (users, industries, skills, roles, permissions, documents).
  - item dengan `permission:` → tampil bila **superuser** atau permission ada di `conn.assigns.permissions`.

## 5. Penerapan (surface bukti)

### 5.1 Memberships (`/memberships`) — permission `members:manage`
- Route dipindah dari gate superuser → gate `[:browser, :require_member]` + `RequirePermission("members:manage")`.
- **Scoping**: superuser → semua membership; non-superuser → **hanya** membership dengan `organization_id == active_organization_id`.
- CRUD (create/edit/delete) diizinkan bagi pemegang `members:manage` **pada org aktifnya** (membership baru otomatis di org aktif). Superuser tetap bebas.
- Menu "Memberships": `permission: "members:manage"`.

### 5.2 Organizations (`/organizations`) — `organizations:read` / `organizations:manage`
- Route gate `[:browser, :require_member]` + `RequirePermission("organizations:read")`.
- **Scoping**: superuser → semua org + boleh **create/delete** (buat/hapus tenant = aksi platform). Non-superuser → **hanya melihat org aktifnya** (index = 1 baris) dan **edit** org itu bila punya `organizations:manage`. **Tanpa** create/delete tenant.
- **read vs manage**: tombol & aksi Edit hanya untuk `organizations:manage`; New/Delete hanya superuser; `organizations:read` = lihat saja.
- Menu "Organizations": `permission: "organizations:read"`.

### 5.3 Superuser & global
Superuser bypass (perilaku admin saat ini tak berubah — lihat semua). Menu & route global (users/industries/skills/roles/permissions/documents) tetap `visible: :superuser` / gate superuser.

## 6. Non-Tujuan (iterasi ini)
- **UI org switcher** (default org dulu; multi-org terkunci ke org pertama sampai switcher ada).
- **Ash policies / `authorize?: true`** (menyusul selektif untuk enforcement lapisan-data + auto-filter tenant).
- Enforcement pada resource **global** (industries/skills/dll tetap superuser).
- Fitur `courses`/`jobs` (belum ada / di luar scope).
- Perubahan skema (tak ada migrasi — murni logika + UI).

## 7. Verifikasi

Temp ExUnit di TEST DB + `mix format` + suite hijau. Kasus uji:
- `permissions_for`/`can?`: coordinator (role `coordinator` di org O, punya `members:manage`+`organizations:read`) → izinnya benar untuk O, **kosong** untuk org lain (tak bocor lintas-org). Superuser → `can?` selalu true.
- **Menu**: coordinator melihat item Memberships (+ Organizations) tapi **tidak** users/industries/dll; user tanpa izin → item hilang; superuser → semua.
- **Route**: coordinator akses `/memberships` OK; user tanpa `members:manage` → redirect. `/organizations` butuh `organizations:read`.
- **Scoping**: coordinator di `/memberships` hanya melihat membership org-nya (bukan org lain); di `/organizations` hanya org-nya.
- **read vs manage**: `organizations:read` (tanpa manage) → tak ada tombol/aksi Edit (aksi update ditolak); dengan `organizations:manage` → boleh edit org-nya; New/Delete tetap hanya superuser.
- Superuser → semua surface tampil penuh, lintas-org.

## 8. Iterasi Berikutnya (di luar spec ini)
- Org switcher (top bar) untuk user multi-org.
- Adopsi Ash policy selektif (resource org-scoped) → enforcement lapisan-data + policy-filter tenant otomatis.
- Perluas ke fitur per-org lain saat dibangun (courses/jobs/members portal).
- Katalog permission untuk resource yang belum tercakup bila diperlukan.
