# Ringkasan Project untuk Abstrak — Atveti Stellar

> Dokumen ini adalah hasil eksplorasi codebase yang ditulis netral dan fokus pada project-nya saja. Setiap klaim dapat ditelusur ke file/code yang disebutkan di bagian Referensi. Istilah teknis Inggris dipakai seperti biasa. Hal yang masih berupa desain/dokumentasi atau belum terverifikasi di code ditandai secara eksplisit agar tidak dipakai sebagai klaim pasti di abstrak.

---

## 1. Nama & Tagline Project

- **Nama:** **Stellar** — di frontend dinamai **Atveti Stellar** (judul aplikasi Flutter: `Atveti Stellar`; `apps/stellar_fe/lib/main.dart`, `apps/stellar_fe/pubspec.yaml`: *"Atveti Stellar — unified Online Learning & AI Job Placement frontend"*).
- **Karakter produk:** Satu platform terpadu dengan dua sisi produk: **Online Learning (LMS)** dan **AI Job Placement**. Di frontend ini dimwujudkan sebagai satu landing page → auth bersama → onboarding → dashboard dengan sakelar **Learn | Jobs** (dijelaskan di `CLAUDE.md` bagian *Flutter frontend structure*).
- **Sifat deployment saat ini:** Berdasarkan code saat ini, backend adalah Elixir umbrella yang di-release sebagai satu rilis OTP `stellar` (`mix.exs` root: `releases: [stellar: [...]]`, dibangun via `MIX_ENV=prod mix release stellar` di `Dockerfile`), dan frontend adalah satu aplikasi Flutter yang di-serve sebagai Flutter Web (unified, via container Nginx; `docker-compose.yml` / `docker-compose.fullstack.yml`).

---

## 2. Latar Belakang / Masalah yang Diselesaikan

Berdasarkan fitur-fitur yang ada di code, project ini menjawab beberapa masalah berikut (framing ini adalah inferensi dari fitur, bukan klaim statistik — perhatikan poin "hal yang belum dijelaskan code"):

1. **Pembelajaran tidak terstruktur dan tidak terukur.** Platform menyediakan jalur belajar yang terstruktur: katalog course → class/kelas dengan jadwal & kapasitas → enrollment → materi/dokumen → VOD. `apps/stellar_lrn` (`StellarLrn.Learning.Course/Class/Enrollment`) dan `docs/api/learning.md` menunjukkan model *Section → Course → Class → Enrollment* di mana siswa mendaftar ke **Class** (satu penyelenggaraan course oleh satu pengajar), bukan sekadar ke Course.
2. **Akses materi tidak terkontrol.** Sistem visibility & tenancy mengatur siapa bisa melihat apa: course `is_public` vs org-scoped, class diikat ke satu organization, dan materi adalah dokumen (`StellarDoc.Documents.Document`) dengan `course_id` (materi course) vs tanpa `course_id` (materi/dokumen pengajar). Ditambah `DocumentAccessGrant` untuk sharing ala dokumen kolaboratif (daftar share per email + masa berlaku — lihat router `/api/documents/:id/grants`).
3. **Lebar jurang antara belajar dan kerja.** Logo produk *Online Learning & AI Job Placement* + halaman Jobs di Flutter (`apps/stellar_fe/lib/jobs/`) + permission `jobs:read / jobs:post / jobs:manage / jobs:apply` + AI agent `HeadHunter` (`apps/stellar_ai/lib/agents/head_hunter.ex`) menunjukkan niat menutup jurang dari pelatihan → lowongan kerja. **Catatan penting untuk abstrak:** berdasarkan code saat ini, halaman Jobs masih **UI-only dengan data sample hard-coded** (`jobs_data.dart` berisi 6 lowongan contoh; dinyatakan "UI-only — no backend wiring, no persistence" di `CLAUDE.md`) dan `apps/stellar_job` masih **stub kosong**. Jadi fitur job placement backend belum terimplementasi — lihat bagian Batasan.
4. **Kolaborasi butuh real-time dan kontrol akses per peran.** Live streaming kelas via WebRTC (SFU + TURN), notifikasi real-time, dan RBAC multi-tenant dipakai agar kelas, materi, dan data organisasi tidak bocor lintas organisasi.
5. **Pengelolaan multi-organisasi yang rumit.** Model *multi-tenant* (`organizations` sebagai tenant) + RBAC per-org dirancang agar satu platform bisa dipakai banyak perusahaan / institusi pendidikan secara terisolasi, dengan admin platform (superuser) sebagai pengendali lintas-tenant.

---

## 3. Tujuan & Manfaat bagi User

Tujuan umum (dari code): **menyediakan satu platform untuk mengelola learning, pengajaran, dan penyaluran kerja dengan kontrol akses berbasis organisasi.**

| Segmen | Tujuan / manfaat yang terlihat di fitur |
|---|---|
| **Learner / worker / graduate (individu)** | Belajar terstruktur dengan katalog course yang org-scoped, mendaftar ke class sesuai jadwal, membuka materi & VOD, ikut sesi live, membayar course berbayar via Stripe, menerima notifikasi real-time. Tipe akun `:personal` (individu, email bebas) di `stellar/accounts/account_type.ex`. |
| **Teacher / pengajar** | Mengampu class (satu class = satu pengajar), mengelola dokumen/materi, memulai sesi live kelas, menerima undangan sebagai guru via email (token). Role `teacher` di seed RBAC; flow undangan di `stellar/invitations/`. |
| **Employer (perusahaan)** | Mengelola organisasi & membernya, melihat dashboard, posting/kelola lowongan (permission `jobs:post/jobs:manage` di desain RBAC). **Catatan:** posting lowongan backend belum terimplementasi (stub) — manfaat ini masih pada level permission/design. |
| **Coordinator (institusi pendidikan)** | Mengelola member & course untuk tenant-nya (`courses:manage`, `members:manage`), mengundang/mendaftarkan peserta didik. Termasuk dalam role seed `coordinator`. |
| **Superuser / admin platform** | Akses penuh lintas-tenant (`users.is_superuser = true`, bypass semua izin): kelola users, organizations, skills/industries/sections, roles/permissions, documents, teacher invitations (API `/api/admin/*` hanya superuser). |

Manfaat cross-cutting yang terlihat di code:

- **Personalisasi onboarding:** progres onboarding 0–100 + `mandatory_completed` (`stellar/accounts/user.ex`), snapshot jawaban onboarding yang disimpan offline-first (`PUT /api/onboarding/answers`, last-write-wins), dan data master referensi (`/api/industries`, `/api/countries`, `/api/skills`, `/api/professions`) untuk memilih industri/skill.
- **Pembayaran aman:** enrolment berbayar via Stripe (PaymentIntent/Checkout/Subscription + webhook terverifikasi signature), pembayaran kartu di Flutter (`flutter_stripe`).
- **Kontrol keamanan berlapis:** JWT Bearer (access ~1 jam, refresh ~30 hari dengan rotasi), WebSocket dengan token JWT, RBAC per-org, dan org-scoping pada semua query katalog.

---

## 4. Solusi / Gambaran Produk (Alur Utama End-to-End)

Berikut alur berdasarkan code yang terverifikasi. Alur yang hanya ada di dokumen desain (`docs/01–10`) ditulis sebagai "desain / belum terverifikasi di code" agar tidak diklaim sebagai fitur jadi.

### 4.1 Landing → Auth → Onboarding → Dashboard (alur utama, terverifikasi)

1. **Landing.** Pengunjung membuka landing page Flutter (`StellarLandingPage` — hero, program, steps/milestone, stats, testimonials, FAQ di `landing/sections/`). *Catatan: dapat memuat angka/estimasi pemasaran — jangan dipakai sebagai klaim faktual sebelum diverifikasi tim.*
2. **Auth.** Login/registrasi lewat satu pintu:
   - **Google OAuth** (web redirect untuk CMS/LiveView; `id_token` untuk Flutter via `POST /api/auth/google` dengan verifikasi audience = `GOOGLE_CLIENT_ID`), **atau**
   - **Email + password** (`POST /api/auth/register`, `POST /api/auth/login`); password min. 8 karakter, di-hash dengan Bcrypt (`stellar/accounts/user.ex`).
   Respons selalu `{ user, token, refresh_token }`. Untuk endpoint terproteksi, klien mengirim `Authorization: Bearer <access_token>`; saat 401 karena kadaluarsa, klien memanggil `POST /api/auth/refresh` (refresh lama dicabut/rotasi) lalu mengulang request (`docs/api/auth.md`).
   **Pembeda tipe akun:** `account_type = :personal` (individu) vs `:organization` (Corporation/Institution) — tipe organisasi wajib email kantor dan email gratisan/publik ditolak (`EmailDomains`). Akun Google baru memilih tipe saat onboarding.
3. **Onboarding wajib.** Pengguna yang belum `mandatory_completed` diarahkan ke `OnboardingFlow` (role-adaptive: employer/coordinator/worker/graduate) sebelum dapat memakai dashboard/explore/quiz/VOD/documents/jobs (`lib/main.dart` route guard). Progress disimpan via `POST /api/onboarding/progress` dan snapshot jawaban via `PUT /api/onboarding/answers`. Akun organisasi yang belum disetujui (`approved != true`) hanya ke halaman *OrgPending* ("request received").
4. **Dashboard adaptif per peran.** Home diputuskan server-side oleh state session (`_homeFor` di `main.dart`): superuser → Teacher Invitations admin; teacher → Teacher dashboard/workspaces (dokumen); org → dashboard (bila approved) atau *pending*; selain itu → onboarding atau dashboard umum dengan sakelar **Learn | Jobs**.

### 4.2 Katalog & Enrollment (Learning) — terverifikasi

- Siswa melihat course yang **org-scoped**: course hanya terlihat bila aktif (`is_active`) dan dibagikan ke organisasi tempat siswa aktif menjadi member (`course_organizations`); class hanya terlihat bila `organization_id` termasuk org user (`docs/api/learning.md` + `docs/specs/2026-07-22-student-rest-api-design.md`).
- Detail course (`GET /api/catalog/courses/:id`) mengembalikan section, industries, materials course, dan daftar class beserta `schedule` (daftar sesi eksplisit `[{date, start, end}]`), `capacity` (null = tak terbatas), `seats_left` (capacity − enrollment aktif), `instructor`, status `enrolled`, dan materials per-class (gabungan materi course + materi pengajar — `StellarLrn.Learning.materials_for_class/1`).
- **Enroll:** `POST /api/classes/:id/enroll` → `201 { enrollment_id, class_id, status: active }`; `409 already_enrolled` bila sudah terdaftar (unique `class_id + student_id`); `409 full` bila kapasitas habis (`CheckCapacity` di `stellar_lrn`). Unenroll via `DELETE`. Daftar enrollment user: `GET /api/me/enrollments`.
- Kelas yang diampu pengajar: `GET /api/me/classes` — dipakai untuk memulai sesi live per-kelas.
- **Course berbayar:** `Course.price_cents` (nil/0 = gratis, satu-tap enroll; >0 = wajib kartu Stripe). Alur berbayar: `POST /api/classes/:id/enroll/intent` (mint PaymentIntent) → konfirmasi server-side `POST /api/classes/:id/enroll/confirm`. Piutang subscription juga tersedia sebagai API pembayaran umum (`/api/payments/*`).

### 4.3 Materi / Dokumen & VOD — terverifikasi (model baru)

- **Dokumen sebagai materi** (`StellarDoc.Documents.Document`): polymorphic via `course_id` — terisi = *course_document*; null = *user_document* (bank dokumen). Atribut: `title`, `url`, `mime_type`, `description`, `user_id` (pengunggah/pemilik), `organization_id` (tenant).
- **Upload dokumen non-video** (PDF/Word/dll): mint presigned URL S3-compatible via `POST /api/documents/upload-url`, lalu simpan record via `POST /api/documents`. **Upload video** dilakukan sebagai dokumen VOD via Cloudflare Stream: `POST /api/vod/documents/upload-url` → `POST /api/vod/documents` → `GET /api/vod/documents/:uid/status`.
- **Sharing akses** ala Google Docs: daftar share per-dokumen (`GET|POST /api/documents/:id/grants`, `DELETE /api/documents/:id/grants/:grant_id`) dengan email + masa berlaku + pemilik/admin-org sebagai pengelola.
- **VOD terkelola:** Cloudflare Stream (upload → transcode → HLS/DASH → CDN) di `apps/stellar_ms` di balik facade `StellarMs` (`create_direct_upload/1`, `get_video/1`, `normalize/1`, `verify_webhook/2`, `hls_url_for/1`). Webhook Cloudflare diverifikasi (HMAC-SHA256, constant-time). Storage file non-video: S3-compatible (Cloudflare R2 / AWS S3 / MinIO) via `StellarMs.S3Storage`. Di Flutter, pemutaran HLS dengan `video_player` (web pakai HTML `<video>`; native pakai HLS native), lengkap dengan checkpoint seekbar, topic drawer, dan panel transkrip (`lib/vod/`).
- **Catatan penting:** Model lama *Lecture + transkrip/checkpoint otomatis* telah **dihapus** (desain `docs/specs/2026-07-22-course-ecosystem-design.md` §2.2: "buang VOD sepenuhnya", Course-Lecture lama diganti Course-Class-Enrollment). Jadi jangan menulis klaim "Lecture dengan checkpoint otomatis hasil transkrip Whisper" sebagai fitur jadi — itu hanya ada di dokumen desain `docs/04` yang sudah ditandai superseded.

### 4.4 Sesi Live (WebRTC) — terverifikasi

- Topik `live_room:<room_id>` via `StellarWeb.LiveRoomChannel` yang mem-proxy semua call SFU ke `StellarMs.Realtime` (Cloudflare Realtime SFU + TURN). **Secret Cloudflare tidak pernah ke klien** — klien hanya menerima ICE servers berumur pendek + SDP.
- **Otorisasi room berbasis kelas:** untuk room `class:<class_id>`, role diturunkan di server dari `StellarLrn.Learning.live_role/2` (pengajar → `host`, siswa ter-enroll aktif → `guest`); payload `role` dari klien diabaikan. User yang bukan pengajar & tidak ter-enroll ditolak. Discovery peserta & track pakai `Phoenix.Presence`; mode: `classroom` / `one_on_one` / `coaching`; perintah host (`end`/`mute`/`remove`) tersedia.
- Di Flutter tersedia modul `live/` (video tile, participant layout, control bar) dengan `flutter_webrtc` + `phoenix_socket`.

### 4.5 Real-time Socket & Notifikasi — terverifikasi sebagian

- **Socket terautentikasi JWT:** `ws://host/socket/websocket?token=<jwt>` (`stellar_web` endpoint `/socket` → `UserSocket`). Channel yang terpasang di code saat ini: `user:notifications:*` (`NotificationChannel`) dan `live_room:*` (`LiveRoomChannel`). Komentar code menegaskan channel lain (progress/chat/quiz/ai_assistant) **menyusul** — jangan diklaim sebagai sudah ada.
- **Notifikasi:** Pengiriman in-app lewat `user:notifications:<user_id>` (hanya pemilik topik yang boleh join; verifikasi token JWT saat handshake). Mailer Swoosh via SMTP Zoho dipakai untuk email undangan teacher. **Desain** `docs/06` (FCM + Oban push background) belum terverifikasi di code (tidak ada `firebase_messaging` di `pubspec.yaml`) — perlakukan sebagai rencana.

### 4.6 Quiz / Asesmen / Sertifikat — DESAIN (belum terverifikasi di backend)

- Dokumen `docs/07` (placement, lecture-level, section-level, live quiz & poll, gamifikasi leaderboard) dan `docs/08` (progress heartbeat 5 detik, gating 90%/70%/75%, sertifikat PDF bertanda SHA256 + verifikasi QR `GET /verify/certificate/:hash`) adalah **spesifikasi desain yang canggih, tetapi backend-nya belum terverifikasi di code**: `apps/stellar_quiz` adalah stub kosong (tanpa dependency), dan tidak ditemukan resource `Quiz/Question/Submission/EnrollmentProgress/Certificate` di code saat ini. Di Flutter ada UI `QuizPage` + widget (leaderboard, poll, countdown, score ring, matching board) tetapi dengan data sample (konsisten dengan "UI-only" di `CLAUDE.md`). Untuk abstrak, bahas ini sebagai **rencana/fitur yang dirancang**, bukan produk jadi.

### 4.7 Job Placement & AI Matching — DESAIN / UI PROTOTYPE (belum terverifikasi di backend)

- Frontend Jobs (`apps/stellar_fe/lib/jobs/`) adalah board lowongan contoh dengan sample hard-coded (contoh: Front Office Associate — Hospitality; Site Supervisor — Construction; Support Worker & Enrolled Nurse — Healthcare; Warehouse Coordinator — Logistics; Guest Services Lead). Fitur yang terlihat: daftar + pencarian, kartu lowongan dengan `matchPct`, halaman detail dengan highlights & requirements. **Tidak ada pemanggilan backend.**
- `apps/stellar_job` masih stub tanpa dependency. `apps/stellar_ai` berisi agent Jido minimal: `TeacherAssistant` (model `:chat`, instruksi as asisten pengajar vokasi) dan `HeadHunter` (model `:thinking`, instruksi sebagai konselor karier, dibatasi untuk tidak menjanjikan placement) + skills `Calculator/Calendar/Clock`. TODO matching berbasis skill diakui di code sebagai belum dibuat.
- **RAG:** `apps/stellar_rag` sudah punya klien *Atomic Server* (`AtomicClient`, `Indexer`, `Extractor` dengan `xberg` untuk ekstraksi teks/gambar) + UI *RAG Ingestion Center* di LiveView (`StellarWeb.RagLive`: pilih course, pilih visibility `private/public/published`, upload dokumen langsung ke vector library per-course per-org, daftar + hapus atoms). Ini adalah **jalur ingestion yang terverifikasi**; sedangkan desain `docs/09` (pgvector `DocumentEmbedding`, retrieval visibility-aware, streaming AI assistant via channel `user:ai_assistant:*`) belum terverifikasi sebagai layanan Q&A end-to-end (channel tersebut tidak terpasang di `UserSocket`).

### 4.8 Undangan Teacher & Admin CMS — terverifikasi

- Superuser membuat undangan email → gabung organisasi dengan role sistem (default `teacher`): token acak URL-safe unik, status `pending → accepted/revoked`, kedaluwarsa default 7 hari, `resend` memperpanjang TTL + bump counter, email via SMTP Zoho (Swoosh). Accept dilakukan lewat halaman Flutter `/invite?token=...` (publik, token-gated: `GET|POST /api/invitations/:token[/accept]`).
- **CMS admin:** LiveView + AshAdmin: `is_superuser` membuka menu global (users, industries, skills, roles, permissions, sections, documents); org-scoped LiveView per permission untuk organizations, memberships, membership_roles, courses, classes, enrollments, documents, teachers (`router.ex` + `stellar_web/live/admin/*`). Halaman web CMS memakai **session cookie + Google OAuth redirect** (Ash `register_with_google`), berbeda dari API Flutter yang memakai JWT Bearer.

---

## 5. Fitur Utama per Peran

| Peran | Akses & fitur terverifikasi (code) | Permission seed (desain `users_and_roles.md` §5.2) |
|---|---|---|
| **Superuser** (platform, `is_superuser=true`, bukan role) | Bypass semua izin, lintas-tenant. API admin `/api/admin/teacher-invitations` (create/resend/index), `/api/admin/organizations`. LiveView global: users, skills, roles, permissions, industries, sections, documents. Mengirim resend undangan. | Semua izin (bypass) |
| **Employer** | Memiliki tenant organisasi; onboarding organisasi; dashboard Learn/Jobs; permission untuk posting & kelola lowongan (belum ada backend jobs — design). | `dashboard:view`, `organizations:read`, `members:manage`, `jobs:post`, `jobs:manage` |
| **Coordinator** | Mengelola member & course tenant-nya (LiveView org-scoped: memberships, courses, classes, enrollments, documents bila punya permission). | `dashboard:view`, `users:read`, `members:manage`, `courses:manage` |
| **Teacher** | Workspace teacher (dokumen/material), dashboard guru, memulai sesi live kelas yang diampu (`GET /api/me/classes` + `live_role` → host). Diundang via email teacher. | `dashboard:view`, `courses:read`, `courses:manage` |
| **Worker / Graduate** | Katalog course org-scoped, enroll ke class (gratis/berbayar Stripe), materi + VOD, sesi live sebagai guest bila ter-enroll, notifikasi real-time. | Worker: `dashboard:view`, `courses:read`, `jobs:read`, `jobs:apply`; Graduate: `dashboard:view`, `jobs:read`, `jobs:apply` |
| **Guest / pengunjung** | Hanya landing page (katalog publik pun pada dasarnya butuh Bearer — dari `docs/api/learning.md`, semua endpoint katalog/enrollment mewajibkan JWT; katalog `published` untuk tamu hanya ada di desain `docs/03`, belum terverifikasi di API aktual). | — |

**Catatan RBAC aktual:** Implementasi yang terverifikasi adalah RBAC **data-driven per-org** (bukan `ash_rbac` code-defined seperti di desain awal): `permissions / roles / role_permissions / memberships / membership_roles`, engine `Stellar.Authz.permissions_for/can?/active_org_id` di `apps/stellar/lib/stellar/authz.ex`, plug `AssignActiveOrg` + `RequirePermission` + `RequireMember`, org aktif disimpan di session, dan org switcher (`POST /switch-org`). Role global (org NULL) vs custom per-org didukung skemanya; role yang di-seed: employer, coordinator, teacher, worker, graduate (+ `default` untuk user baru).

**Master data yang membedakan individu vs organisasi:** `account_type`, validasi email kantor, data referensi industries/countries/skills/professions (`stellar/orgs/` + `*_data.ex`), sertifikasi & skill user (desain onboarding), dan `UserDetail` (interest/resume/education/organization/training_offers) untuk profil job placement.

---

## 6. Arsitektur Teknis

```
Client: Flutter Web (unified, apps/stellar_fe) ─┐   (single codebase: landing→auth→
                                                │    onboarding→dashboard Learn|Jobs)
                                                ▼
Backend: Phoenix 1.8 API + LiveView (apps/stellar_web, :4000)
  ├─ HTTP JSON API /api/* (Bearer JWT, CORS)
  ├─ WebSocket /socket (Phoenix Channels, JWT handshake)
  ├─ LiveView CMS /dashboard, /rag, /my/documents, /courses, /classes, ...
  └─ AshAdmin /admin (superuser)
        ▼
Domain layer (Ash resources + domains, AshPostgres)
  ├─ apps/stellar      — core: Accounts, Orgs, Rbac, Payments, Invitations, Repo
  ├─ apps/stellar_lrn  — Learning (Section/Course/Class/Enrollment)
  ├─ apps/stellar_doc  — Documents (bank dokumen + access grants)
  ├─ apps/stellar_ms   — media leaf (Cloudflare Stream VOD + Realtime SFU/TURN, S3)
  ├─ apps/stellar_rag  — RAG ingestion (Atomic Server client + xberg extractor)
  ├─ apps/stellar_ai   — AI agents (Jido: TeacherAssistant, HeadHunter)
  └─ apps/stellar_job / stellar_rt / stellar_quiz — stubs (konteks cadangan)
        ▼
Data & infra: ParadeDB (PostgreSQL + pgvector-capable image) :5438
  + Cloudflare Stream/Realtime, S3-compatible (R2/S3/MinIO), Stripe,
    Google OAuth2, SMTP Zoho (Swoosh), Oban (Postgres-backed queue)
```

Penjelasan per lapisan (semua terverifikasi di file konfigurasi & code):

- **Elixir umbrella:** 10 apps child (`stellar`, `stellar_job`, `stellar_lrn`, `stellar_ai`, `stellar_doc`, `stellar_ms`, `stellar_quiz`, `stellar_rag`, `stellar_rt`, `stellar_web`) satu rilis `stellar`. Arah dependensi: `stellar_web → stellar → stellar_ms` (leaf, tanpa dependency umbrella untuk menghindari cycle) dan `stellar_lrn → stellar + stellar_doc`. Komentar `CLAUDE.md`: "Put new backend code in the app that owns that concern".
- **Orang tidak boleh tertipu dokumen arsitektur lama:** `docs/01` menggambarkan ElectricSQL/`ash_sync`, Membrane MPLS, dan FLM — tetapi `docs/04` dan code aktual menunjukkan VOD kini lewat Cloudflare Stream terkelola (bukan self-hosted Membrane/S3), dan sync offline-first aktual di Flutter memakai **Drift + SQLite (outbox) + `connectivity_plus`**, bukan ElectricSQL. Istilah "elasticsql" di dokumen adalah penamaan internal untuk ElectricSQL yang tidak terbukti dipakai di `pubspec`/`mix.exs` aktual.
- **Realtime scaling (desain):** Phoenix PubSub + `pg` clustering untuk broadcast lintas-node; setiap ruangan chat/quiz dirancang sebagai GenServer per-room lewat DynamicSupervisor dengan write-back buffer (30 detik / 20 pesan) — lihat desain `docs/05`.
- **Offline-first (aktual, Flutter):** `Session` + `SyncEngine` + `OutboxDb` (Drift) untuk antrian mutasi saat offline, dengan prefetch `sqlite3.wasm` + splash progress saat startup web agar DB lokal langsung siap.
- **Deploy:** `Dockerfile` backend (multi-stage, Debian glibc agar NIF Rust `xberg` bisa di-force-build dari source), `docker-compose*.yml` (ParadeDB + backend + FE Nginx), healthcheck (`pg_isready`, `curl /`), migrasi + seed otomatis saat boot (`bin/migrate`, `bin/seed` via `Stellar.Release.seed/0` yang idempoten), dan CI/CD pipeline umum `audit → build → deploy` via SSH + docker-compose (tanpa menyebut provider CI tertentu).

---

## 7. Teknologi yang Dipakai (Ter verifikasi dari `mix.exs` / `pubspec.yaml` / `Dockerfile`)

### Backend (Elixir / Phoenix / Ash)

- Elixir `~> 1.15–1.19` (`.tool-versions`: Elixir 1.19.5 / Erlang 27.3.4.3), Phoenix `~> 1.8.9`, `phoenix_live_view ~> 1.1.0`, `phoenix_live_dashboard`, Bandit.
- Ash Framework `~> 3.0` + `ash_postgres ~> 2.0` + `ash_authentication ~> 4.0` (+ `ash_authentication_phoenix ~> 2.0`) untuk user & Google OAuth; `ash_oban ~> 0.8.10` + `oban ~> 2.20` untuk queue job Postgres-backed; `ash_rbac ~> 0.6` terdaftar di `mix.exs` (desain RBAC aktual data-driven — lihat `docs/specs/2026-07-21-rbac-enforcement-design.md`).
- `ecto_sql ~> 3.13` + `postgrex` (PostgreSQL/ParadeDB), `jason`, `swoosh ~> 1.16` + `gen_smtp` (SMTP Zoho untuk email undangan), `req ~> 0.5` (HTTP client — tanpa httpoison/tesla/httpc), `cors_plug`, `dotenvy`, `picosat_elixir`, `phoenix_pubsub`, `dns_cluster`, `telemetry_metrics/poller`, `esbuild` + `tailwind 4.1.12` untuk asset web.
- Media: `stellar_ms` hanya `req` + `plug_crypto` (leaf). **AI/RAG:** `stellar_ai`: `jido_ai ~> 2.1` + `jido_chat ~> 1.0`; `stellar_rag`: `rustler` + `xberg ~> 1.0.0-rc.14` (`force_build: true`, HEIF/HEIC image support, butuh Rust toolchain + `libheif1`).

### Frontend (Flutter)

- Flutter/Dart SDK `^3.12.0`; `google_fonts` (Poppins), `cupertino_icons`.
- Auth & storage: `google_sign_in` (+ `google_sign_in_web` karena GIS button di web), `flutter_secure_storage`.
- Local DB/offline: `drift` + `drift_flutter`, `connectivity_plus`, `uuid`, `build_runner` + `drift_dev`.
- Video & live: `video_player` (HLS VOD), `flutter_webrtc`, `phoenix_socket`, `file_picker`, `http_parser`, `web`.
- Payments: `flutter_stripe` + `flutter_stripe_web`.
- HTTP: `http` (Dart API client di `lib/services/`).

### Data, media, infra

- **ParadeDB** (`paradedb/paradedb:latest`, port host `5438 → 5432`, healthcheck `pg_isready`).
- **Cloudflare Stream** (VOD: direct upload, transcode, HLS/DASH, webhook HMAC-SHA256) dan **Cloudflare Realtime** (SFU + TURN untuk live WebRTC; secret tetap di server).
- **S3-compatible storage** (Cloudflare R2 / AWS S3 / MinIO) via presigned upload untuk dokumen non-video.
- **Stripe** (PaymentIntent/Checkout/Subscription/webhook; test keys via env, publishable key dibake ke FE).
- **Google OAuth2**, **SMTP Zoho** (Swoosh), **Atomic Server** (RAG vector library, `stellar-rag.onprem.vip`, token via `ATOMIC_API_TOKEN`).
- Docker multi-stage + docker-compose; nginx untuk FE web; CI/CD beku `API_BASE_URL` & `GOOGLE_CLIENT_ID` sebagai Dart define saat build.

### Hal yang tampaknya dipakai tapi tidak terverifikasi di dependensi aktual

- `firebase_messaging` / FCM — tidak ada di `pubspec.yaml` (Hanya analisis desain `docs/06` yang menyebutnya).
- ElectricSQL / `ash_sync` — tidak ada di `mix.exs`/`pubspec.yaml` (sync aktual pakai Drift/outbox).
- `membrane` / pipeline transcode self-host — tidak ada di dependensi (diganti Cloudflare Stream terkelola).
- LinkedIn OAuth — dirujuk di desain (`users_and_roles.md`: strategi `linkedin` + sinkron skill) tetapi tidak ada dependensi/endpoint terverifikasi di code yang dibaca; perlakukan sebagai rencana.

---

## 8. Model Bisnis / Dampak Sosial (Bila terlihat dari code/docs — tanpa mengarang angka)

- **Monetisasi yang terverifikasi di code:** Course berbayar via `price_cents` (satuan sen mata uang terkecil, default `usd`) + Stripe (PaymentIntent sekali bayar, Checkout Session, Subscription). Ini memungkinkan model **freemium** (course gratis satu-tap vs berbayar kartu) dan **langganan**. Tidak ada angka harga/pendapatan di code — jangan menulis angka di abstrak.
- **B2B / institusi multi-tenant:** Organisasi (perusahaan & institusi pendidikan) adalah tenant dengan enrollment & material miliknya sendiri; keanggotaan & permission per-org memungkinkan model **SaaS per-tenant** atau penyelenggaraan pelatihan in-house. Undangan teacher ke organisasi menunjukkan rantai pasok pengajar yang dibina via organisasi.
- **AI Job Placement (visi produk):** UI Jobs + permission `jobs:*` + agent `HeadHunter` menandakan jalur pendapatan berikutnya lewat rekrutmen/matching. **Namun backend jobs masih stub** — pada abstrak, sampaikan ini sebagai "arah pengembangan yang dirancang" bukan fitur yang sudah menghasilkan placement.
- **Dampak sosial yang dapat dipertahankan dari code (tanpa angka):** jebatan akses belajar terstruktur yang org-scoped, kelas dengan jadwal & kuota yang jelas, media VOD + dokumen yang terkontrol, sesi live terisolasi per kelas (hanya pengajar & siswa ter-enroll), sertifikasi/skill/informasi profesi sebagai data dasar onboarding, dan peluang job-board lintas industri (sample UI meliputi hospitality, konstruksi, healthcare, logistik). Dampak yang lebih besar (jumlah lulusan, tingkat placement, retensi) tidak dapat diklaim karena tidak ada data di repo — tandai sebagai "perlu diisi tim" bila ingin mencantumkan angka dampak.

---

## 9. Batasan / Hal yang Belum Dijelaskan Code ("Perlu Diisi Tim")

1. **Angka & klaim dampak:** Jumlah user, course, enrollment, retention, placement rate, NPS, pendapatan — tidak ada di repo. Perlu data riil dari tim/pilot sebelum dicantumkan.
2. **Keaslian landing page:** Angka statistik/estimasi di landing (`stats_milestone`, `readiness_gauge`) dan contoh lowongan (`matchPct`, gaji) adalah **sample marketing/UI** — jangan dipakai sebagai hasil studi.
3. **Job Placement end-to-end (AI matching, lowongan backend, aplikasi, kurasi):** masih stub/UI-only. Jelaskan sebagai "dirancang / prototipe frontend" bila disebut di abstrak.
4. **Quiz/asesmen ber-gating + sertifikat PDF terverifikasi:** masih desain (`docs/07–08`) + UI Flutter sample; tidak ada resource backend terverifikasi.
5. **AI Assistant RAG Q&A & vector search end-to-end:** ingestion ke Atomic Server terverifikasi; retrieval/streaming jawaban belum terverifikasi sebagai channel live.
6. **FCM/push notifikasi background, ElectricSQL sync, LinkedIn skill sync, Membrane pipeline, live chat/poll/quiz channel:** desain yang belum terbukti di dependensi/channel aktual.
7. **Doku arsitektur lama (`docs/01–10`) vs implementasi aktual:** Beberapa dokumen mengandung penamaan lama (mis. ElectricSQL disebut "elasticsql", tabel `DocumentEmbedding` pgvector, lecture HLS self-host). Gunakan code (`mix.exs`, `pubspec.yaml`, `router.ex`, resource files) sebagai sumber kebenaran, bukan dokumen desain.
8. **Profil/gambar produk untuk abstrak:** Demo/deploy URL, akun demo, video, screenshot — perlu disiapkan tim (repo hanya menyediakan cara menjalankan lokal).
9. **Legal/izin:** Penggunaan Cloudflare, Stripe, Google OAuth di production, dan kebijakan data pribadi perlu dilengkapi tim bila abstrak memuat aspek komersial/legal.

---

## 10. Draf Poin-Poin Siap Pakai untuk Menyusun Abstrak (5–7 Bullet)

- **Masalah:** Pembelajaran vokasi terfragmentasi, akses materi tak terkontrol, dan kesenjangan pelatihan → kerja yang sulit dijembatani dalam satu sistem yang aman multi-organisasi.
- **Solusi terpadu:** Atveti Stellar adalah platform **Online Learning & AI Job Placement** dalam satu pengalaman (landing → auth → onboarding → dashboard Learn|Jobs) yang dibangun di atas Elixir/Phoenix + Ash dan Flutter Web.
- **Learning terstruktur & berkapasitas:** Model `Section → Course → Class → Enrollment` multi-tenant; katalog org-scoped, jadwal per-class, `seats_left`, enrollment gratis satu-tap atau berbayar Stripe, dengan materi/dokumen & VOD HLS (Cloudflare Stream) yang terkelola.
- **Pengajaran live yang terkontrol:** Sesi WebRTC (Cloudflare Realtime SFU + TURN) di mana role host/guest diturunkan di server dari enrollment kelas; real-time via Phoenix Channels dengan JWT + RBAC per-org yang data-driven.
- **Personalisasi & produktivitas:** Onboarding wajib dengan progres & snapshot offline-first (Drift outbox), master data industri/skill/profesi, bank dokumen dengan sharing per-grant, RAG ingestion per-course ke Atomic Server, agent AI (TeacherAssistant & HeadHunter berbasis Jido), dan notifikasi real-time.
- **Status jujur produk:** Backend learning, payment Stripe, dokumen/VOD, live, dan admin RBAC terverifikasi di code; job-placement backend, quiz ber-gating, sertifikat, dan AI Q&A streaming masih berstatus desain/prototipe UI — dapat menjadi *roadmap* abstrak.
- **Siap deploy:** Dirilis sebagai satu OTP release via Docker Compose (ParadeDB + backend + FE Nginx), dengan CI pipeline umum audit → build → deploy dan healthcheck.

---

## 11. Draf Paragraf Abstrak Singkat (~200 kata)

Atveti Stellar adalah platform terpadu Online Learning dan AI Job Placement yang dirancang untuk menjembatani kesenjangan pelatihan menuju kerja, dalam satu pengalaman web dari landing, auth, onboarding, hingga dashboard dengan sakelar Learn dan Jobs. Berbasis Elixir/Phoenix dan Ash Framework, platform ini memodelkan pembelajaran sebagai Section menuju Course menuju Class menuju Enrollment secara multi-tenant, dengan katalog course yang org-scoped, jadwal dan kapasitas per-kelas, materi sebagai dokumen terkelola, serta Video-on-Demand HLS melalui Cloudflare Stream. Siswa dapat mendaftar gratis atau berbayar via Stripe, pengajar mengelola dokumen dan memulai sesi live WebRTC (SFU dan TURN) yang otorisasinya diturunkan di server dari enrollment kelas, sementara notifikasi dan kolaborasi berjalan real-time melalui Phoenix Channels dengan JWT dan RBAC per-organisasi yang data-driven. Onboarding yang terpersonalisasi, bank dokumen dengan sharing per-grant, ingestensi RAG per-course ke Atomic Server, dan agent AI untuk pendampingan belajar dan konseling karier melengkapi nilai tambah produk. Penempatan kerja backend, kuis bergating, sertifikat, dan AI Q&A streaming masih berstatus desain/prototipe pada codebase saat ini, menjadi roadmap pengembangan selanjutnya. Solusi ini dikemas dalam release OTP Docker Compose dengan ParadeDB dan CI/CD umum, siap diuji pada pilot organisasi dan institusi pendidikan.

*(Jumlah kata ±200 — dapat dipadatkan/diperluas mengikuti batas kata lomba; jangan menambahkan angka dampak atau klaim fitur backend jobs/quiz/sertifikat sebagai produk jadi.)*

---

## 12. Kata Kunci (Keywords) untuk Abstrak

`Online Learning, LMS, AI Job Placement, Elixir, Phoenix, Ash Framework, Flutter, WebRTC, Cloudflare Stream, Realtime SFU, RAG, RBAC, Multi-Tenant, JWT, Stripe, ParadeDB, Real-Time, Vocational Training, Offline-First`

---

## 13. Daftar File Referensi (Sumber yang Dipakai)

**Project & panduan:**
- `README.md` (panduan menjalankan backend umbrella)
- `mix.exs` (root umbrella: 10 apps, rilis `stellar`)
- `CLAUDE.md` (struktur frontend Flutter + peta backend app-per-bounded-context)
- `Dockerfile`, `docker-compose.yml`, `docker-compose.fullstack.yml`, `docker-compose.dev.yml`
- `config/config.exs`, `config/runtime.exs`

**Dokumen desain (dipakai hanya untuk fitur yang benar-benar ada, ditandai bila desain):**
- `docs/01_architecture_overview.md` — `docs/10_user_onboarding.md`
- `docs/api/auth.md`, `docs/api/learning.md`
- `docs/specs/2026-07-21-rbac-enforcement-design.md`, `docs/specs/2026-07-22-course-ecosystem-design.md`, `docs/specs/2026-07-22-student-rest-api-design.md`
- `docs/enhancement/users_and_roles.md`
- `docs/enhancement/media_streaming_vod_integration.md` (tidak dibaca langsung, dirujuk dari `docs/04`)

**Backend Elixir:**
- `apps/stellar/mix.exs`, `apps/stellar_web/mix.exs`, `apps/stellar_ms/mix.exs`, `apps/stellar_lrn/mix.exs`, `apps/stellar_doc/mix.exs`, `apps/stellar_rag/mix.exs`, `apps/stellar_ai/mix.exs`, `apps/stellar_job/mix.exs`, `apps/stellar_rt/mix.exs`, `apps/stellar_quiz/mix.exs`
- `apps/stellar/lib/stellar/accounts/user.ex`, `apps/stellar/lib/stellar/accounts/account_type.ex`
- `apps/stellar/lib/stellar/rbac/role.ex`, `apps/stellar/lib/stellar/orgs/organization.ex`
- `apps/stellar/lib/stellar/invitations/invitation.ex`
- `apps/stellar/lib/stellar/payments/README.md`
- `apps/stellar_lrn/lib/stellar_lrn/learning/course.ex`, `class.ex`, `enrollment.ex`
- `apps/stellar_doc/lib/stellar_doc/documents/document.ex`
- `apps/stellar_ms/lib/stellar_ms/cloudflare_stream.ex`, `cloudflare_realtime.ex`
- `apps/stellar_web/lib/stellar_web/router.ex`, `endpoint.ex`, `channels/user_socket.ex`, `channels/live_room_channel.ex`, `live/rag_live.ex`
- `apps/stellar_ai/lib/agents/teacher_assistant.ex`, `head_hunter.ex`
- `apps/stellar_rag/lib/stellar_rag/*`

**Frontend Flutter:**
- `apps/stellar_fe/pubspec.yaml`, `apps/stellar_fe/README.md`, `apps/stellar_fe/lib/main.dart`
- `apps/stellar_fe/lib/jobs/data/jobs_data.dart`, `apps/stellar_fe/lib/shared/onboard_role.dart`
- `apps/stellar_fe/lib/services/` (`auth_api.dart`, `sync/`, `courses_api.dart`, `documents_api.dart`, `vod_api.dart`, `vod_document_api.dart`)
- `apps/stellar_fe/lib/landing/`, `dashboard/`, `onboarding/`, `explore/`, `quiz/`, `vod/`, `live/`, `jobs/`, `teacher/`, `admin/`, `invite/`, `documents/` (struktur direktori)
