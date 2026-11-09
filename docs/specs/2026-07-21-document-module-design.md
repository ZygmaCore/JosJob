# Spec — Modul Document (Bank Dokumen)

**Tanggal:** 2026-07-21
**Status:** Disepakati untuk diimplementasi (menunggu review spec)
**Konteks:** Stellar (Elixir umbrella, Ash Framework + AshPostgres, Phoenix LiveView/daisyUI). Multi-tenant.

---

## 1. Ringkasan

Modul **Document** — abstraksi "bank dokumen" tunggal (polymorphic) untuk menyimpan referensi berkas milik course maupun user, lengkap dengan aturan visibilitas multi-tenant. **Independen**: tidak dikaitkan ke modul course/class/material — `course_id` hanya nilai uuid biasa (penanda), tanpa relasi/FK.

Dua jenis kepemilikan dalam satu tabel:
- **course_document** — `course_id` terisi. Pemilik = pengunggah (mis. teacher/admin).
- **user_document** — `course_id` null. Pemilik = pengunggah (mis. worker/graduate).

## 2. Keputusan Kunci (hasil brainstorming)

| Topik | Keputusan |
|---|---|
| Penempatan | Domain **`StellarDoc.Documents`** di **`apps/stellar_doc`** (app `:stellar_doc`, namespace `StellarDoc`). |
| Struktur | **Satu tabel `documents`** polymorphic (bukan dua tabel). `owner_kind` diturunkan dari `course_id` (terisi/null). |
| Penyimpanan | **URL saja** — DB simpan `url` + metadata. Upload file asli DI LUAR cakupan (belum ada object storage). |
| `mime_type` | Kolom **`mime_type`** (string, nullable) menyimpan mimetype dokumen (mis. `application/pdf`, `video/mp4`). Bukan kategori/enum. |
| Scoping tenant | Kolom **`organization_id` eksplisit** di tiap dokumen (di-stamp saat upload). Filter "org sama" langsung. |
| Kopling course | `course_id` = **uuid lepas** (tanpa FK/relasi). Modul independen dari course. |
| Admin-org | Ditentukan dari **daftar role yang dapat dikonfigurasi** (`@org_admin_roles`, default `["coordinator"]`) via membership. Superuser di atas semua. |
| UI | **Admin superuser** (lihat/kelola semua) **+ portal user** (user login lihat `visible_to` dirinya + upload/hapus miliknya). |

## 3. Penempatan & Wiring (`apps/stellar_doc`)

Domain **`StellarDoc.Documents`**, resource **`StellarDoc.Documents.Document`** — `otp_app: :stellar_doc`, `data_layer: AshPostgres.DataLayer`, **`repo: Stellar.Repo`** (satu DB).

Arah dependency satu arah: **`stellar_web → stellar_doc → stellar`**.
- `apps/stellar_doc/mix.exs`: tambah `{:stellar, in_umbrella: true}` (untuk `Stellar.Accounts.User`, `Stellar.Orgs.Organization`, `Stellar.Repo`, dan `Stellar.Rbac.{Role, MembershipRole}` + `Stellar.Orgs.Membership` untuk helper visibilitas) + `{:ash, "~> 3.0"}`, `{:ash_postgres, "~> 2.0"}`.
- `apps/stellar_web/mix.exs`: tambah `{:stellar_doc, in_umbrella: true}` (admin + portal merender dokumen).
- `config/config.exs`: tambah `config :stellar_doc, ash_domains: [StellarDoc.Documents]`; tambahkan juga `StellarDoc.Documents` ke `config :stellar_web, ash_domains` (agar tooling via endpoint melihatnya).
- Migrasi tetap ke `Stellar.Repo` → file di `apps/stellar/priv/repo/migrations`.
- `course_id` uuid lepas → tak ada kopling app; tak memicu circular dependency.

## 4. Skema `documents`

```
documents
  id                uuid (pk)
  user_id           uuid  FK → users          (pengunggah = pemilik, wajib)
  organization_id   uuid  FK → organizations  (tenant, wajib)
  course_id         uuid  nullable            (terisi = course_document; null = user_document; TANPA FK)
  title             string  (wajib)
  url               string  (wajib — link berkas)
  mime_type         string  (opsional — mimetype, mis. "application/pdf", "video/mp4")
  description       string  (opsional)
  created_at, updated_at
```

- `mime_type` = tipe/mimetype dokumen (bukan enum kategori). **Tanpa** FK untuk `course_id`.
- Pengunggah/pemilik = `user_id`; waktu unggah = `created_at`.
- Index: `organization_id`, `user_id`, `course_id` (untuk filter visibilitas).
- Relasi Ash: `belongs_to :user` (Stellar.Accounts.User), `belongs_to :organization` (Stellar.Orgs.Organization). `course_id` = attribute uuid biasa.

## 5. Visibilitas — `StellarDoc.Documents.visible_to/1`

`visible_to(current_user)` mengembalikan query/daftar dokumen yang boleh dilihat, sebagai **union**:

- **superuser** (`users.is_superuser`) → **semua** dokumen.
- **admin-org** → semua dokumen dengan `organization_id` ∈ {org tempat user jadi admin}. "Admin-org" = punya **membership aktif** di org tsb dengan role (via `membership_roles → roles.key`) yang ada di **`@org_admin_roles`** (default `["coordinator"]`; daftar mudah diubah).
- **selalu** → dokumen miliknya sendiri (`user_id == current_user.id`).

Catatan: "milik sendiri" cukup `user_id == self` — teacher/worker/graduate sama-sama melihat dokumen yang mereka unggah; pembedaan course_document vs user_document tetap ada di data (`course_id`) tapi tidak mempengaruhi aturan "lihat milik sendiri".

Enforcement: helper ini dipakai controller untuk memfilter (query-scope), **bukan** Ash policy global. Ini menjadi cikal-bakal enforcement RBAC yang lebih luas nanti.

## 6. UI

Satu resource, dua permukaan (keduanya daisyUI):

1. **Admin superuser** — `/documents` di area admin (pipeline `[:browser, :require_admin]`, pola admin yang ada): superuser melihat **semua** dokumen, filter per organisasi, buat & hapus. Kolom: pemilik (email), organisasi, jenis (course/user berdasarkan `course_id`), title, url, created_at. Entri nav "Documents".
2. **Portal user** — halaman ber-gate `[:browser, :require_member]` (mis. `/my/documents`): user login melihat dokumen `visible_to(dirinya)` + **upload** (form: `title`, `url`, `mime_type` opsional, `description`, pilih **organisasi** dari membership-nya, `course_id` opsional) + hapus dokumen miliknya. Admin-org otomatis melihat seluruh dokumen se-org di sini.

Saat upload di portal: `user_id = current_user`, `organization_id` = org yang dipilih (opsi = organisasi tempat user jadi member), `course_id` = opsional (dikosongkan → user_document).

## 7. Cakupan & Non-Tujuan

**Termasuk (iterasi ini):** resource `Document` (Ash) + CRUD dasar (create/read/delete) + helper `visible_to/1` + migrasi + admin superuser UI + portal user UI + verifikasi.

**Di luar cakupan:**
- Upload file asli ke object storage (URL saja dulu).
- Kategori/enum jenis dokumen (yang ada hanya `mime_type` untuk menyimpan mimetype).
- Enforcement RBAC penuh / Ash policy (visibilitas via query-scope dulu).
- Org switcher (portal upload memakai daftar membership user apa adanya).
- Kaitan ke modul course/class/material (independen).

## 8. Migrasi

Buat tabel `documents` (kolom §4) + index FK. Tabel baru, **non-destruktif**. Dijalankan **oleh user** (`mix ecto.migrate`); asisten hanya menyiapkan kode & verifikasi di TEST DB.

## 9. Verifikasi

Pola repo: temp ExUnit di TEST DB, lalu dihapus; `mix format` bersih; suite hijau. Kasus uji:
- Buat course_document (course_id terisi) & user_document (course_id null) → tersimpan benar.
- `visible_to`: superuser lihat semua; admin-org (member ber-role coordinator) lihat se-org; user biasa hanya miliknya; user lain tidak bocor.
- Admin superuser `/documents`: render + filter org + create + delete; gate non-superuser.
- Portal `/my/documents`: user lihat `visible_to` dirinya + upload (org dari membership) + hapus miliknya; gate non-member.

## 10. Iterasi Berikutnya (di luar spec ini)
- Upload file asli (object storage R2/S3) menggantikan URL manual.
- Enforcement RBAC penuh (visibilitas jadi bagian policy).
- Kategori/`type` bila diperlukan untuk filter/tampilan.
- Org aktif/switcher untuk konteks upload.
