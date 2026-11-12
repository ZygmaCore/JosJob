# JosJob - Online Learning & Job Placement

JosJob menghubungkan pencarian kerja dan
pembelajaran. Backend memakai Elixir/Phoenix, Ash Framework, dan PostgreSQL;
frontend terpadu memakai Flutter. Arah produk adalah **Match -> Gap -> Learn ->
Re-match**: mencocokkan CV dengan lowongan, mengenali kekurangan skill,
merekomendasikan pembelajaran, lalu mencocokkan ulang.

**Status saat ini:** katalog pembelajaran, enrollment, dokumen, integrasi media,
dan CRUD lowongan sudah tersedia. Analisis CV, ranking AI, rekomendasi berbasis
gap skill, saved jobs, dan pengiriman lamaran masih merupakan pekerjaan terencana.

## Fitur dan batas implementasi

| Area | Implementasi saat ini |
| --- | --- |
| Akun dan organisasi | Registrasi/login email-password pada API, Google OAuth, JWT dengan refresh token, membership dan izin berbasis organisasi |
| Onboarding | Progress dan jawaban dengan outbox lokal Drift/SQLite, retry dan sinkronisasi saat tersambung kembali |
| Lowongan | Pencarian, filter, pagination, detail, serta editor employer untuk membuat, memperbarui dan menghapus lowongan |
| Pembelajaran | Section, course, class, enrollment, materi, undangan teacher dan pembayaran enrollment melalui Stripe |
| Dokumen | Metadata, upload melalui URL bertanda tangan ke storage kompatibel S3, serta akses berdasarkan pemilik, organisasi dan grant |
| Media | Upload VOD Cloudflare Stream dan signaling kelas live melalui Cloudflare Realtime |
| RAG | Ekstraksi dan ingestion dokumen ke Atomic Server; asisten percakapan lengkap belum tersedia |
| Admin | LiveView dengan pemeriksaan membership/permission dan akses superuser sesuai route |

Lowongan dibatasi oleh organisasi dan izin `jobs:read`, `jobs:post` atau
`jobs:manage`. Pengguna tanpa organisasi/izin yang sesuai menerima daftar kosong.
Lowongan baru berstatus draft; employer berizin dapat mempublikasikannya melalui
editor. Data contoh lama hanya menjadi fixture test, bukan hasil matching AI atau
lowongan yang otomatis di-seed. Lihat [kontrak jobs API](docs/api/jobs.md).

Outbox offline saat ini hanya mencakup progress dan jawaban onboarding.
Channel notifikasi tersedia sebagai fondasi join/ping, belum sebagai sistem
pengiriman notifikasi lengkap. Integrasi eksternal memerlukan kredensial masing-masing.

## Arsitektur dan struktur repositori

Backend merupakan modular monolith: sepuluh aplikasi Elixir dalam satu umbrella,
satu release OTP `josjob`, satu endpoint Phoenix, dan database bersama melalui
`Josjob.Repo`. Flutter berada di repositori yang sama tetapi di luar daftar app Mix.

| Direktori | Tanggung jawab |
| --- | --- |
| `apps/josjob` | Akun, organisasi, RBAC, pembayaran, Repo, migrasi dan seed |
| `apps/josjob_web` | HTTP/JSON API, LiveView admin, autentikasi web dan Phoenix Channels |
| `apps/josjob_job` | Resource lowongan, pencarian dan operasi employer dengan pembatasan organisasi |
| `apps/josjob_lrn` | Katalog, kelas, enrollment dan materi pembelajaran |
| `apps/josjob_doc` | Dokumen dan grant akses |
| `apps/josjob_ms` | Provider media Cloudflare dan storage kompatibel S3 |
| `apps/josjob_rag` | Ekstraksi dan ingestion dokumen |
| `apps/josjob_ai` | Kerangka agent Jido; analisis CV dan matching masih direncanakan |
| `apps/josjob_quiz`, `apps/josjob_rt` | App scaffold; signaling aktif berada di `josjob_web` |
| `apps/josjob_fe` | Flutter client, layanan API, session dan outbox onboarding |
| `config/`, `rel/`, `deployment/` | Konfigurasi, helper release dan berkas deployment |
| `docs/`, `PRD/`, `e2e/` | Dokumentasi teknis, spesifikasi produk dan Playwright |

Migrasi database berada di `apps/josjob/priv/repo/migrations`.
[Project map](docs/PROJECT_MAP.md) menyediakan penelusuran fitur dan sumber;
beberapa inventarisnya mendeskripsikan snapshot lama. Gunakan source dan test
terkini untuk memverifikasi perilaku.

## Menjalankan stack lokal dengan Docker

Gunakan Docker dengan dukungan Linux containers dan Docker Compose v2 yang
mendukung `env_file.required`. Cara ini juga menghindari kendala build native
Windows pada dependensi Rust/NIF `xberg`.

1. Buat direktori `envs` dan file `envs/.env` di root repositori.
2. Isi konfigurasi lokal berikut, lalu sesuaikan akun seed bila diperlukan:

```dotenv
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=josjob_dev
POSTGRES_HOST=localhost
POSTGRES_PORT=5438
PORT=4000
API_BASE_URL=http://localhost:4000
FE_BASE_URL=http://localhost:8081
SEED_SUPERUSER_EMAIL=admin@example.com
SEED_SUPERUSER_PASSWORD=local-dev-password-123
```

`envs/` diabaikan Git. Compose full stack menyediakan secret default untuk
preview lokal; deployment memerlukan `SECRET_KEY_BASE` dan
`TOKEN_SIGNING_SECRET` sendiri. Keduanya dapat dibuat dengan `mix phx.gen.secret`.

3. Jalankan dari root repositori:

```bash
docker compose -f docker-compose.fullstack.yml --env-file envs/.env up -d --build
docker compose -f docker-compose.fullstack.yml --env-file envs/.env logs -f josjob_be
```

| Layanan | Alamat lokal |
| --- | --- |
| Flutter web | http://localhost:8081 |
| Phoenix API dan login web | http://localhost:4000 |
| ParadeDB/PostgreSQL | `localhost:5438` |

Backend menunggu database sehat, menjalankan migrasi, mencoba seed, lalu
menjalankan server. Kegagalan seed dicatat tetapi tidak menghentikan server;
periksa log jika akun awal atau data katalog tidak muncul. Seed membuat akun
superuser yang dapat login melalui Flutter dengan email/password di atas.

Gunakan `-f docker-compose.fullstack.yml` secara eksplisit: `docker-compose.yml`
hanya mendefinisikan database dan frontend. Di jaringan container, backend
mengakses database melalui `paradedb:5432`; port `5438` dipakai dari host.

Untuk menghentikan stack tanpa menghapus volume database:

```bash
docker compose -f docker-compose.fullstack.yml --env-file envs/.env down
```

## Pengembangan backend di host

Gunakan Linux/WSL atau lingkungan dengan toolchain native yang kompatibel.
Versi tool dipatok di [`.tool-versions`](.tool-versions): Elixir
`1.19.5-otp-27`, Erlang `27.3.4.3`, Node `24.13.0`, dan Rust `1.96.1`.
`xberg` dibangun dari source sehingga memerlukan Rust serta dependensi build native.
Database harus mendukung PostgreSQL 16+.

Dengan `envs/.env` seperti di atas dan database berjalan:

```bash
docker compose --env-file envs/.env up -d paradedb
mix deps.get
mix ecto.setup
mix assets.setup
mix assets.build
iex -S mix phx.server
```

`mix ecto.setup` membuat database, menjalankan migrasi dan seed.
Konfigurasi runtime dibaca dari `envs/.env`, file
`envs/.<environment>.overrides.env` dan environment proses; environment proses
memiliki prioritas tertinggi. `DATABASE_URL` dapat menggantikan `POSTGRES_*`.
Variabel `SEED_SUPERUSER_*` dibaca langsung dari environment proses: untuk
seed di host, export/set variabel tersebut pada shell sebelum `mix ecto.setup`.

## Pengembangan Flutter

Gunakan Flutter dengan Dart yang memenuhi `^3.12.0` sesuai
[`pubspec.yaml`](apps/josjob_fe/pubspec.yaml).

```bash
cd apps/josjob_fe
flutter pub get
flutter run -d chrome --web-port=8081 --dart-define=API_BASE_URL=http://localhost:4000
```

`API_BASE_URL` dan `GOOGLE_CLIENT_ID` adalah konfigurasi saat build. Untuk
Google sign-in, tambahkan `--dart-define=GOOGLE_CLIENT_ID=<google-web-client-id>`.
Pada Docker, isi variabel yang sama di `envs/.env`, lalu rebuild `josjob_fe`.
Mengubah environment backend saja tidak memperbarui bundle Flutter.
Lihat [panduan frontend](apps/josjob_fe/README.md) untuk defines file dan aset
SQLite WASM/Drift.

## Autentikasi dan integrasi

Login browser Phoenix berada di `/` dan memakai Google OAuth; logout di
`/sign-out`. Admin menggunakan route LiveView seperti `/users`, `/organizations`
dan `/courses` dengan gate masing-masing. Tidak ada route `/admin` atau `/sign-in`.

Untuk OAuth browser, isi `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, dan
`GOOGLE_REDIRECT_URI=http://localhost:4000/auth`. Daftarkan callback
`http://localhost:4000/auth/user/google/callback` pada Google OAuth client.
Untuk Flutter web, daftarkan juga origin `http://localhost:8081`.

| Endpoint API | Kegunaan |
| --- | --- |
| `POST /api/auth/register` | Registrasi email/password |
| `POST /api/auth/login` | Login email/password |
| `POST /api/auth/google` | Login menggunakan Google `id_token` |
| `POST /api/auth/refresh` | Rotasi refresh token dan penerbitan pasangan token baru |
| `/api/jobs` | Browse dan CRUD lowongan dengan Bearer access token |

TTL default access token adalah 1 jam dan refresh token 30 hari, dapat diubah
melalui `ACCESS_TOKEN_TTL` dan `REFRESH_TOKEN_TTL` (detik).
Socket terautentikasi tersedia di
`ws://localhost:4000/socket/websocket?token=<access_token>`, dengan topik
`user:notifications:<user_id>` dan `live_room:class:<class_id>`.

Konfigurasi integrasi ada di [`config/runtime.exs`](config/runtime.exs):

| Integrasi | Variabel utama |
| --- | --- |
| Pembayaran Stripe | `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET` |
| Cloudflare Stream VOD | `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_STREAM_TOKEN` |
| Cloudflare Realtime | `CLOUDFLARE_REALTIME_APP_ID`, `CLOUDFLARE_REALTIME_APP_SECRET`, `CLOUDFLARE_TURN_KEY_ID`, `CLOUDFLARE_TURN_TOKEN` |
| Storage dokumen | `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`; opsional `S3_REGION`, `S3_PUBLIC_BASE_URL` |
| Email undangan | `SMTP_RELAY`, `SMTP_USERNAME`, `SMTP_PASSWORD`; opsi TLS/port dan alamat pengirim di runtime config |

RAG memerlukan Atomic Server; URL dan `ATOMIC_API_TOKEN` dikonfigurasi di
[`config/config.exs`](config/config.exs), termasuk pembacaan environment saat
konfigurasi build. Compose full stack tidak menyediakan Atomic Server.

## Pemeriksaan dan test

Dari root, jalankan pemeriksaan backend yang diwajibkan repositori:

```bash
mix precommit
```

Alias ini berjalan dalam environment test dan menjalankan compile dengan
warnings sebagai error, `deps.unlock --unused`, format dan test. Periksa diff
setelahnya karena alias dapat mengubah file. `mix test` dapat dipakai untuk
menjalankan suite secara terpisah.

Database test memakai `josjob_test` dengan suffix opsional
`MIX_TEST_PARTITION`. Konfigurasi test membaca `POSTGRES_*` langsung dari
environment proses; set pada shell jika berbeda dari default
`postgres/postgres` di `localhost:5438`.

Dari `apps/josjob_fe`:

```bash
flutter analyze
flutter test
```

Test `_tmp_register_flow_test.dart` memiliki keterbatasan import browser-only
pada Flutter VM; lihat [catatan verifikasi jobs](docs/api/jobs.md#verification).
Untuk E2E, jalankan stack terlebih dahulu, lalu dari `e2e`:

```bash
npm ci
npx playwright install chromium
npm test
```

Set `BASE_URL=http://localhost:8081`, `TEST_EMAIL` dan `TEST_PASSWORD` pada
shell atau `e2e/.env` sebelum test. Test login menargetkan DOM semantics Flutter;
default port `4000` pada konfigurasi Playwright perlu di-override.

## Dokumentasi dan deployment

- [Panduan transisi nama aplikasi dan instalasi lama](docs/REBRANDING.md)
- [Project map dan hubungan fitur](docs/PROJECT_MAP.md)
- [PRD utama](PRD/PRD.md) dan [keputusan produk](PRD/DECISIONS.md)
- [API autentikasi](docs/api/auth.md), [pembelajaran](docs/api/learning.md), dan [lowongan](docs/api/jobs.md)
- [Konfigurasi Compose full stack](docker-compose.fullstack.yml) dan [Compose deployment dev](docker-compose.dev.yml)

Release backend bernama `josjob`; helper migrasi, seed dan server berada di
`rel/overlays/bin`. Checkout ini tidak menyertakan workflow CI/CD, sehingga
pipeline deploy otomatis tidak dapat diasumsikan tersedia.

Lisensi: [GNU Affero General Public License v3](LICENSE).
