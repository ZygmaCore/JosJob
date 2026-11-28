# PRD — Users, Multi-Tenant & Roles/Permissions

**Status:** Draft (disepakati untuk diimplementasi)
**Konteks:** JosJob (Elixir umbrella, Ash Framework + AshPostgres, Phoenix). Platform Online Learning + AI Job Placement, **multi-tenant**.

---

## 1. Ringkasan

Mendefinisikan ulang model **user, identitas, profil, organisasi (tenant)**, dan sistem **roles & permissions** berbasis DB yang **di-scope per-tenant**. Menggantikan pendekatan lama yang memakai kolom `users.roles text[]` hardcode (tanpa konsep permission dan tanpa scoping tenant).

Prinsip inti:
- **Satu identitas global per orang** (1 email = 1 user), bisa login via **email+password, Google, atau LinkedIn**.
- **Multi-tenant**: user menjadi **anggota (member)** banyak organisasi via tabel `memberships`.
- **Role & permission per-tenant**: hak akses dihitung dari role user **pada organisasi yang sedang aktif**, tidak pernah digabung lintas-organisasi.
- **Superuser = level platform** (di luar tenant), bypass semua.

---

## 2. Tujuan & Non-Tujuan

### Tujuan
1. Skema `users` baru (profil lengkap) + 3 metode registrasi (email/password, Google, LinkedIn).
2. Perbaikan `user_identities` (link OAuth multi-provider yang benar).
3. Modul **user profile/detail** (`user_details`) — dilihat via klik nama user di list.
4. Modul **organizations** (tenant) lengkap dengan CRUD + UI.
5. Sistem **RBAC data-driven**: `permissions`, `roles`, `role_permissions`, `memberships`, `membership_roles`.
6. Alur **multi-org**: pilih/ganti organisasi aktif (org switcher); hak akses & data ter-scope ke org aktif.

### Non-Tujuan (fase ini)
- Role **custom per-organisasi** yang bisa dibuat/diedit tenant sendiri (skema sudah mendukung, tapi mulai dari **role global/sistem** dulu).
- UI manajemen role↔permission (izin cukup **di-seed dari kode** dulu).
- Sinkronisasi skill/pengalaman dari LinkedIn API (butuh akses API terbatas — proyek terpisah).
- Konfirmasi email lewat pengiriman email (boleh menyusul; lihat §6.1).

---

## 3. Istilah

| Istilah | Arti |
|---|---|
| **Tenant** | Organisasi (`organizations`). Batas isolasi data & hak akses. |
| **Identitas global** | Baris `users` — satu orang, satu email, lintas semua tenant. |
| **Membership** | Keanggotaan user di sebuah organisasi (`memberships`). |
| **Role** | Kumpulan permission (mis. `coordinator`). Global (sistem) atau custom per-org. |
| **Permission** | Kapabilitas granular `resource:action` (mis. `users:manage`). Didefinisikan di kode. |
| **Org aktif** | Organisasi yang sedang dilihat user di sesi (satu pada satu waktu). |
| **Superuser** | Admin **platform** (`users.is_superuser`), bypass semua, lintas-tenant. |

---

## 4. Model Data

> Perubahan dari draft lama: **`users.roles text[]` DIHAPUS** → diganti `is_superuser` + RBAC via membership. Semua timestamp `created_at`/`updated_at`. Email `citext` (case-insensitive). FK diberi index.

### 4.1 `users` — identitas global
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | |
| email | citext | no, unique | case-insensitive; 1 email = 1 user |
| full_name | varchar | no | untuk OAuth diisi dari profil Google/LinkedIn |
| hashed_password | varchar | yes | null utk user OAuth-only; wajib hanya di action register-email |
| phone | varchar | yes | ternormalisasi E.164 |
| address | text | yes | |
| birthdate | date | yes | validasi `<= hari ini` |
| avatar_url | varchar | yes | dari Google/LinkedIn |
| confirmed_at | timestamp | yes | jalur password: setelah konfirmasi; OAuth: langsung terisi |
| **is_superuser** | boolean | no (default false) | admin PLATFORM (pengganti roles text[]) |
| created_at | timestamp | no (default now()) | |
| updated_at | timestamp | yes | |

### 4.2 `user_identities` — link OAuth
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | PK tunggal (bukan komposit) |
| user_id | uuid | no, FK → users (ON DELETE CASCADE) | |
| strategy | varchar | no | `"google"` / `"linkedin"` |
| uid | varchar | no | `sub` dari provider |
| access_token | text | yes | |
| refresh_token | text | yes | |
| access_token_expires_at | timestamp | yes | |
| created_at | timestamp | no (default now()) | |
| updated_at | timestamp | yes | jejak refresh token / login terakhir per provider |
| | | | **UNIQUE (strategy, uid)** — GABUNGAN, bukan per-kolom |
| | | | **UNIQUE (user_id, strategy)** — 1 user max 1 link per provider |

### 4.3 `user_details` — profil (1:1 dengan user)
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | |
| user_id | uuid | no, unique, FK → users (CASCADE) | **UNIQUE** menjamin 1:1 |
| interest | jsonb | yes | minat (freeform) |
| resume | jsonb | yes | resume terstruktur (freeform) |
| education | jsonb | yes | pendidikan (freeform) |
| organization | jsonb | yes | riwayat organisasi/kerja (freeform — **bukan** relasi ke tabel `organizations`) |
| training_offers | jsonb | yes | penawaran pelatihan (freeform) |
| created_at | timestamp | no (default now()) | |
| updated_at | timestamp | yes | |

### 4.4 `industries`
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | |
| name | varchar | no, unique | |

### 4.5 `organizations` — tenant
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | |
| name | varchar | no | |
| user_id | uuid | no, FK → users | pembuat/pemilik (audit); keanggotaan sesungguhnya via `memberships` |
| industry_id | uuid | yes, FK → industries (SET NULL) | |
| phone | varchar | yes | |
| address | text | yes | |
| additional_info | text | yes | |
| created_at | timestamp | no (default now()) | |
| updated_at | timestamp | yes | |

### 4.6 `memberships` — user ↔ organisasi (INTI multi-tenant)
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | |
| user_id | uuid | no, FK → users (CASCADE) | |
| organization_id | uuid | no, FK → organizations (CASCADE) | |
| status | varchar | no (default 'active') | `invited` / `active` / `suspended` |
| created_at | timestamp | no (default now()) | |
| updated_at | timestamp | yes | |
| | | | **UNIQUE (user_id, organization_id)** |

### 4.7 `permissions` — katalog izin (di-seed dari kode)
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | |
| key | varchar | no, unique | format `resource:action`, mis. `users:manage` |
| description | varchar | yes | |
| category | varchar | yes | pengelompokan (users, jobs, learning, …) |

### 4.8 `roles`
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| id | uuid | no (pk) | |
| organization_id | uuid | yes, FK → organizations (CASCADE) | **NULL = role global/sistem**; terisi = role custom milik org |
| key | varchar | no | mis. `coordinator` |
| name | varchar | no | |
| description | varchar | yes | |
| is_system | boolean | no (default false) | |
| created_at | timestamp | no (default now()) | |
| updated_at | timestamp | yes | |
| | | | **UNIQUE (organization_id, key)** + unique partial `key WHERE organization_id IS NULL` |

### 4.9 `role_permissions` — role punya izin apa (M:N)
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| role_id | uuid | no, FK → roles (CASCADE) | |
| permission_id | uuid | no, FK → permissions (CASCADE) | |
| | | | PK (role_id, permission_id) |

### 4.10 `membership_roles` — role user DI org tsb (M:N)
| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| membership_id | uuid | no, FK → memberships (CASCADE) | |
| role_id | uuid | no, FK → roles (CASCADE) | |
| | | | PK (membership_id, role_id) |

### 4.11 Relasi (ringkas)
```
users ─1:1─ user_details
users ─1:N─ user_identities
users ─1:N─ memberships ─N:1─ organizations ─N:1─ industries
memberships ─M:N(membership_roles)─ roles ─M:N(role_permissions)─ permissions
roles.organization_id NULL = role global
users.is_superuser = admin platform (di luar tenant)
```

### 4.12 Audit trail (`created_by` / `updated_by`)

Untuk keperluan audit ("siapa yang membuat & siapa yang mengubah"), tabel
master/RBAC berikut menambah dua kolom seragam:

| Kolom | Tipe | Null? | Catatan |
|---|---|---|---|
| created_by | uuid | yes | id user pembuat baris — diisi saat **create** |
| updated_by | uuid | yes | id user pengubah terakhir — diisi saat **create & update** |

**Berlaku di:** `industries`, `organizations`, `memberships`, `membership_roles`,
`roles`, `permissions`, `skills`.

- **Pengisian otomatis** dari **actor** (user yang login) lewat Ash change
  `Josjob.Changes.StampActor`: `created_by` di-set saat create; `updated_by`
  saat create **dan** update.
- **Bukan FK** (plain `uuid`) — disengaja, agar jejak audit tetap utuh meski
  user terkait kelak dihapus. **Tidak** termasuk `default_accept` → tak bisa
  diisi lewat form (hanya oleh change).
- **NULL** untuk baris hasil **seed / operasi sistem** (tanpa actor) dan baris
  lama sebelum kolom ini ada.
- Ditampilkan di list admin sebagai **email** pembuat/pengubah (kolom
  "Dibuat oleh" / "Diubah oleh"); resolusi id→email via `JosjobWeb.Audit`.

---

## 5. Katalog Permission & Role Awal (di-seed)

### 5.1 Permission (contoh awal)
`dashboard:view`, `users:read`, `users:manage`, `members:manage`, `organizations:read`,
`organizations:manage`, `courses:read`, `courses:manage`, `jobs:read`, `jobs:post`,
`jobs:manage`, `jobs:apply`.

### 5.2 Role global (sistem) & izinnya
| Role | Permission |
|---|---|
| employer | dashboard:view, organizations:read, members:manage, jobs:post, jobs:manage |
| coordinator | dashboard:view, users:read, members:manage, courses:manage |
| teacher | dashboard:view, courses:read, courses:manage |
| worker | dashboard:view, courses:read, jobs:read, jobs:apply |
| graduate | dashboard:view, jobs:read, jobs:apply |

> `superuser` **bukan** role — diwakili `users.is_superuser = true` (bypass semua izin, lintas-tenant).

---

## 6. Kebutuhan Fungsional

### 6.1 Registrasi & Login
- **Email + password**: input wajib `full_name, email, password`; opsional `phone, address, birthdate`. `hashed_password` diisi; `confirmed_at` null sampai dikonfirmasi.
  - Konfirmasi email: *direkomendasikan* (mencegah email palsu & hijacking). Boleh diaktifkan menyusul; bila belum, tandai sebagai known-gap.
- **Google OAuth**: buat/temukan user by email; **`full_name` diisi dari klaim `name` Google**; `avatar_url` dari `picture`; `confirmed_at` diisi bila `email_verified`. Tambah/temukan baris `user_identities` (`strategy=google`).
- **LinkedIn OAuth** (OpenID Connect): sama polanya (`strategy=linkedin`). Klaim mirip Google (catatan: `locale` berupa objek).
- **Penautan akun**: email sama menyatu ke **satu** `users`. Satu user bisa punya `hashed_password` + beberapa identity OAuth.
- **Hanya `full_name` yang wajib dari OAuth**; `phone/address/birthdate/interest/dst.` lewat form "lengkapi profil".

### 6.2 Multi-Tenant & Org Aktif
- Setelah login, sistem mengambil `memberships` (status `active`) milik user.
  - **0 membership** & bukan superuser → tak punya konteks tenant (arahkan ke halaman "belum tergabung organisasi").
  - **1 membership** → auto-pilih sebagai org aktif.
  - **>1 membership** → **default ke org terakhir dipakai** (atau pertama) + **org switcher** di header. *(Keputusan: default + switcher, bukan picker screen.)*
- **Org aktif disimpan di sesi (web) / JWT (mobile)** sebagai `organization_id`.
- **Ganti org** = set `organization_id` baru → izin, menu, dan data dihitung ulang untuk org itu.
- **Superuser**: konteks **platform** (lintas semua org), bukan satu tenant.

### 6.3 RBAC — Izin Efektif
- Aturan (dijalankan tiap request):
  ```
  is_superuser ? SEMUA izin
               : union(role_permissions) dari membership_roles(user, ORG_AKTIF)
  ```
- **Tidak pernah** menggabungkan izin lintas-organisasi. Multi-role dalam **satu** org boleh (union role-role di org itu).
- **Invarian (app-level):** `membership_roles` hanya boleh menautkan role yang **global (org NULL)** atau **milik org yang sama** dengan membership-nya.

### 6.4 Modul User Detail
- Di list user, **nama user bisa diklik** → halaman detail user.
- Halaman menampilkan data `users` + `user_details` (interest, resume, education, organization, training_offers) + keanggotaan (`memberships` + role per org).
- Fase ini: **tampilan (read)**. Edit profil menyusul.

### 6.5 Modul Organizations (CRUD + UI)
- CRUD penuh: list, create, edit, delete (+ detail).
- Field sesuai §4.5. `industry_id` dipilih dari `industries`.
- Akses: dikelola **superuser** (platform) untuk fase awal; nantinya bisa dibuka ke role ber-izin `organizations:manage`.

### 6.6 Penegakan (Ash + Web)
- **Ash policy**: custom check `Josjob.Authz.Checks.HasPermission("resource:action")` + bypass `Superuser`. Tenant aktif dibawa via konteks/actor.
- **Web**: plug `RequirePermission` (dan/atau `RequireSuperuser`) sebelum controller/LiveView.
- **Bukan** `ash_rbac` (itu code-defined; kita perlu data-driven).

---

## 7. Alur UX (contoh)

### 7.1 Login multi-org (Sari)
Sari `worker` di **PT Maju Jaya** dan `coordinator` di **Politeknik Nusantara**.
```
Login Google → punya 2 membership → default org aktif (mis. terakhir dipakai)
Header: [🏢 PT Maju Jaya ▼]  → switch ke Politeknik kapan saja
```
- **Aktif = PT Maju Jaya** → role `worker` → izin `dashboard:view, courses:read, jobs:read, jobs:apply` → dashboard **pencari kerja**; menu: Jobs, Courses.
- **Aktif = Politeknik** → role `coordinator` → izin `dashboard:view, users:read, members:manage, courses:manage` → dashboard **pengelola**; menu: Members, Courses.
- Ganti org → konteks (izin/menu/data) dihitung ulang. **Tidak digabung.**

### 7.2 Superuser
`is_superuser=true` → view platform (lintas org), akses penuh, tanpa perlu membership.

---

## 8. Rencana Migrasi / Rollout

1. Tambah kolom baru `users` (`full_name`, `hashed_password`, `phone`, `address`, `birthdate`, `avatar_url`, `confirmed_at`, `is_superuser`, timestamps); `email` → `citext`. **Backfill** `full_name` untuk baris lama (mis. dari email) sebelum set NOT NULL.
2. Tambah timestamps di `user_identities`; perbaiki UNIQUE (`strategy,uid` + `user_id,strategy`) & PK tunggal.
3. Buat tabel: `user_details`, `industries`, `organizations`, `memberships`, `permissions`, `roles`, `role_permissions`, `membership_roles` (+ index FK).
4. **Seed**: katalog `permissions`, role global + `role_permissions` (§5).
5. Migrasi data lama: `users.roles` lama → `is_superuser` (untuk yang `superuser`); sisanya via membership saat data org tersedia. Lalu **DROP `users.roles`**.
6. Kode: `register_with_google`/`_linkedin` isi `full_name`/`avatar_url`/`confirmed_at`; ganti check role lama → `HasPermission`; org switcher + org aktif di sesi/JWT.
7. **Enhancement audit trail** (§4.12): tambah kolom `created_by`/`updated_by` (uuid, nullable) di `industries`, `organizations`, `memberships`, `membership_roles`, `roles`, `permissions`, `skills`. **Non-destruktif** (nullable) — baris lama/seed = NULL; terisi otomatis dari actor pada aksi berikutnya.

> Deploy: migrasi otomatis lewat `bin/migrate` di pipeline; seed lewat `bin/seed`.

---

## 9. Keputusan yang Sudah Diambil
- ✅ User **boleh multi-organisasi** → pakai `memberships`.
- ✅ Role **global/sistem dulu** (custom per-org = future). Skema sudah mendukung dua-duanya.
- ✅ `superuser` = **boolean platform** (`is_superuser`).
- ✅ Permission **per-aksi**, **di-seed dari kode** (belum ada UI kelola izin).
- ✅ Izin **tidak digabung lintas-org**; multi-role dalam satu org = union.
- ✅ Multi-org: **default org + switcher** (bukan picker screen).
- ✅ `user_details.organization` = **jsonb freeform** (riwayat kerja/organisasi), bukan relasi tenant.
- ✅ **Audit trail** (§4.12): kolom `created_by`/`updated_by` (uuid, nullable, non-FK) di 7 modul master/RBAC, diisi otomatis dari actor via `Josjob.Changes.StampActor`.

## 10. Pertanyaan Terbuka
1. Konfirmasi email jalur password: aktif sekarang atau menyusul?
2. Kapan mulai role **custom per-org** + UI kelola role↔permission?
3. Provider LinkedIn: konfirmasi pakai *Sign In with LinkedIn using OpenID Connect*.
4. Halaman "belum tergabung organisasi" untuk user tanpa membership — perlu desain?

## 11. Out of Scope (fase ini)
- LinkedIn skill/experience sync (butuh API terbatas).
- Undangan/onboarding member ke organisasi (flow invite) — bisa PRD terpisah.
- Audit log akses berbasis izin.
