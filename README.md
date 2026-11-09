# Stellar — Online Learning & AI Job Placement

Platform terpadu untuk pembelajaran online dan penempatan kerja berbasis AI, digerakkan oleh
Elixir/Phoenix + Ash Framework (backend) dan Flutter (frontend web). Sistem mendukung banyak
peran (employer, coordinator, worker, graduate, superuser) dengan otentikasi Google OAuth, API
token JWT untuk klien mobile, serta notifikasi real-time via WebSocket.

## Arsitektur singkat

- `apps/stellar` — domain inti, context, dan otorisasi berbasis Ash.
- `apps/stellar_web` — endpoint Phoenix, LiveView, dan CMS admin (AshAdmin).
- `apps/stellar_lrn` — modul pembelajaran: katalog kursus, kelas, enrollment, dokumen, dan VOD.
- `apps/stellar_fe` — frontend Flutter web terpadu (auth, dashboard per peran, katalog, dokumen, VOD, offline sync).
- `config/` + `envs/.env` — konfigurasi runtime; database ParadeDB/PostgreSQL via Docker.

Dokumentasi rinci: lihat folder `docs/` (api, laporan, rencana pengembangan).

## Struktur repo

```
.
├── apps/
│   ├── stellar/        # domain + Ash resources
│   ├── stellar_web/    # Phoenix endpoint + admin UI
│   ├── stellar_lrn/    # learning management (katalog, kelas, dokumen, VOD)
│   └── stellar_fe/     # Flutter web frontend
├── config/             # runtime + env config
├── deployment/         # Dockerfile backend (dev/prod)
├── docs/               # dokumentasi API, laporan, dan rencana
├── e2e/                # pengujian end-to-end (Playwright)
├── extensions/         # ekstensi tambahan
├── rel/                # Elixir release
├── docker-compose.yml
├── docker-compose.dev.yml
├── docker-compose.fullstack.yml
└── mix.exs             # umbrella project
```

# Cara Pakai (How to Use)

Panduan menjalankan backend umbrella (Elixir/Phoenix + Ash) secara lokal.

## Prasyarat

- **Docker** & **docker compose** (untuk database ParadeDB).
- **asdf** dengan versi sesuai `.tool-versions`: `elixir 1.19.5-otp-27`, `erlang 27.3.4.3`.
  ```bash
  asdf install
  ```

## 1. Konfigurasi environment

Buat/isi `envs/.env` (dibaca runtime lewat Dotenvy). Contoh minimal:

```env
PORT=4000

# Kredensial DB — SATU skema (POSTGRES_*) untuk semua environment. Nilai berbeda
# per-environment karena tiap env memuat file .env sendiri (lokal / dev / prod).
# Lokal: HOST=localhost PORT=5438; di server, docker-compose memaksa HOST=paradedb.
# (Alternatif: set DATABASE_URL untuk override penuh, mis. managed DB.)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=stellar_dev
POSTGRES_HOST=localhost
POSTGRES_PORT=5438

SECRET_KEY_BASE=<hasil: mix phx.gen.secret>
TOKEN_SIGNING_SECRET=<hasil: mix phx.gen.secret>

# Google OAuth (login). GOOGLE_REDIRECT_URI = BASE ke AuthPlug (bukan callback penuh).
GOOGLE_CLIENT_ID=<client id google>
GOOGLE_CLIENT_SECRET=<client secret google>
GOOGLE_REDIRECT_URI=http://localhost:4000/auth

# TTL token API (detik). Default: access 1 jam, refresh 30 hari.
ACCESS_TOKEN_TTL=3600
REFRESH_TOKEN_TTL=2592000

# Email superuser awal (di-seed). Login via Google dengan email ini = akses CMS.
SEED_SUPERUSER_EMAIL=admin@example.com
```

> **Google Cloud Console** — di OAuth Client ID, daftarkan **Authorized redirect URI**:
> `http://localhost:4000/auth/user/google/callback` (URL FINAL; app merakitnya dari base di atas).

## 2. Database + dependency

```bash
docker compose --env-file envs/.env up -d paradedb   # ParadeDB pakai kredensial POSTGRES_* dari envs/.env
mix deps.get
mix ecto.setup                         # create + migrate + seed (superuser)
# atau: mix ecto.migrate && mix run apps/stellar/priv/repo/seeds.exs
```

## 3. Menjalankan server

```bash
iex -S mix phx.server
```

Aplikasi di `http://localhost:4000`.

## 4. Alur otentikasi (CMS / web)

- **Home**: `http://localhost:4000/` — ada tombol **Login** (di samping Changelog).
- **Login**: `/sign-in` → **Sign in with Google** (login FULL Google OAuth, tanpa password).
- **Admin/CMS**: `/admin` (AshAdmin) — hanya bisa diakses **superuser**. Login dengan akun Google yang emailnya sama dengan `SEED_SUPERUSER_EMAIL`.
- **Logout**: buka `/sign-out` (langsung keluar → kembali ke `/sign-in`).

Role RBAC: `employer`, `coordinator`, `worker`, `graduate`, `superuser` (+ `default` untuk user baru). Hanya `superuser` yang boleh masuk CMS.

## 5. API mobile (Flutter) — token

- **Login**: `POST /api/auth/google` body `{"id_token": "<id_token Google>", "access_token": "..."}`
  → verifikasi id_token → `{ user, token (access 1 jam), refresh_token (30 hari) }`.
- **Refresh**: `POST /api/auth/refresh` body `{"refresh_token": "..."}` → pasangan baru (rotasi; refresh lama dicabut).

Contoh:

```bash
curl -X POST http://localhost:4000/api/auth/google \
  -H 'content-type: application/json' -d '{"id_token":"<id_token>"}'
```

## 6. WebSocket (real-time)

Handshake membawa JWT (access token) sebagai query param:

```
ws://localhost:4000/socket/websocket?token=<access_token>
```

Channel contoh: `user:notifications:<user_id>` (hanya pemilik topik yang boleh join).

## 7. Test

```bash
MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate   # sekali di awal
mix test
```

## 8. CI/CD & Deploy

Pipeline CI/CD menjalankan `audit → build → deploy` saat push/merge ke branch **`develop`**.
Deploy memakai `docker-compose.dev.yml` dengan variable CI `ENV_DEV` (file `.env`) via SSH
ke server, termasuk health-gate dan rollback otomatis bila backend tidak sehat.
