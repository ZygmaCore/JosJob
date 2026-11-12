# Spec — Org Switcher

**Tanggal:** 2026-07-21
**Status:** Disepakati untuk diimplementasi.
**Konteks:** Lanjutan RBAC enforcement. Engine sudah membaca `session["active_organization_id"]` (plug `AssignActiveOrg`) + default membership pertama. Switcher menyediakan UI untuk mengganti org aktif.

## Keputusan
- Dropdown di **top bar** (`Layouts.admin`), **muncul hanya bila user punya ≥2 membership aktif** (tersembunyi untuk 0/1 org & superuser).
- Setelah ganti → redirect **`/dashboard`**.
- Tanpa perubahan skema.

## Komponen
1. **`Josjob.Authz.member_orgs/1`** → daftar `%{id, name}` organisasi tempat user member **aktif** (urut nama). Non-member/`nil` → `[]`.
2. **Plug `AssignActiveOrg`** → tambah `conn.assigns.member_orgs` (superuser → `[]`, tanpa query).
3. **`POST /switch-org`** (gate `[:browser, :require_member]`), `JosjobWeb.OrgSwitchController.update/2`:
   - Validasi `organization_id` ∈ `member_orgs(user)` (kalau bukan → abaikan, tak set).
   - `put_session("active_organization_id", org_id)` → redirect `/dashboard`.
4. **UI** (`Layouts.admin` top bar): dropdown bila `length(member_orgs) >= 2`; menampilkan nama org aktif; tiap item = `<.form method="post" action={~p"/switch-org"}>` + hidden `organization_id` (CSRF otomatis). Org aktif ditandai.
5. **Threading**: `Layouts.admin` dapat attr `active_organization_id` + `member_orgs`; disisipkan ke 28 pemanggilan template setelah `permissions={@permissions}`.

## Keamanan
Switch hanya ke org tempat user benar-benar member aktif (validasi server-side). Request berikutnya `AssignActiveOrg` menghitung ulang izin untuk org baru.

## Non-Tujuan
Superuser impersonate org, org switcher untuk 1-org (tak perlu), persist "org terakhir dipakai" lintas-sesi (session cukup).

## Verifikasi
- `member_orgs` benar (hanya membership aktif, urut).
- `POST /switch-org` ke org member → session ter-set + `visible/permissions` untuk org baru; ke org non-member → diabaikan.
- Dropdown tampil hanya untuk member ≥2 org (bukan 1-org, bukan superuser).
