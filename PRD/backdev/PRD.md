# PRD Backend — JosJob (backdev)

> **Scope dokumen ini:** backend saja (Elixir/Phoenix + Ash, `apps/josjob*`).
> Frontend ada di `../frontdev/PRD.md`. Keputusan level tim ada di `../PRD.md`.
> Dokumen ini ditulis dalam Bahasa Indonesia dengan istilah teknis Inggris.
>
> **Untuk AI-nya backdev:** dokumen ini memberi konteks yang kaya + pilihan
> di setiap keputusan yang belum final. Kalau ada pilihan, **tanyakan ke
> backdev** sebelum mengimplementasikannya — jangan memilih sendiri secara
> diam-diam. Pilihan yang belum diputuskan dikumpulkan di
> `OPEN-QUESTIONS.md`.
>
> **House rules repo (wajib):** `AGENTS.md` di root repo. Yang paling relevan
> untuk pekerjaan ini: HTTP client harus `Req` — **jangan** pakai
> `:httpoison`, `:tesla`, atau `:httpc`. Selesaikan perubahan dengan alias
> `mix precommit` (compile `--warnings-as-errors`, format, test). Migrasi
> dibuat dengan `mix ecto.gen.migration`. Jangan pakai `String.to_atom/1`
> pada input user. Test memakai `start_supervised!/1`, hindari
> `Process.sleep/1`. Satu modul per file (jangan nest module). Field yang
> di-set programatik (misal `user_id`) tidak masuk `cast`, tapi di-set
> eksplisit saat membuat struct. Akses field changeset dengan
> `Ecto.Changeset.get_field/2`.

## 1. Tujuan scope backend

Membangun, di atas JosJob yang sudah ada, semua yang dibutuhkan sisi server
untuk loop **Match → Gap → Learn → Re-match**:

1. Lowongan + lamaran yang sebelumnya hanya UI/stub menjadi backend nyata.
2. CV Analyzer: ekstraksi CV → embedding → ranking + penjelasan.
3. Ranking v1 yang deterministik dan bisa dijelaskan; v2 sebagai desain.
4. Semua itu dengan auth/RBAC yang sudah ada, dan dengan privasi CV yang
   sesuai GDPR.

**Non-goals scope ini:** UI/UX dan copywriting (frontdev), quiz bergating +
sertifikat, RAG Q&A streaming, FCM push, dan monetisasi di luar Stripe yang
sudah ada.

## 2. Arsitektur backend

### 2.1 Keputusan yang sudah final

- **Modular monolith.** Elixir umbrella, 10 apps, satu rilis OTP `josjob`.
  Bukan microservices yang di-deploy terpisah. Alasan: repo sudah seperti
  itu, satu tim kecil, dan deadline hackathon tidak memungkinkan pemecahan
  service.
- **Arah dependensi:** `josjob_web → josjob → josjob_ms` (leaf, tanpa
  dependensi umbrella). Jangan membuat `josjob_ms` bergantung ke `josjob`
  (cycle). Kode baru ditaruh di app yang memiliki concern-nya — jangan
  menumpuk semua di `apps/josjob` + `apps/josjob_web`.
- **Deploy:** Docker Compose di VPS (sudah dites build + deploy JosJob oleh
  user, jalan tanpa user — cukup untuk demo). Domain sudah ada. Cloudflare
  dipakai nanti (bareng streaming yang sudah ada di JosJob). Bila menang
  dan go public, arsitektur deployment dimatangkan lagi.

### 2.2 App yang dipakai dan yang dibangun baru

| App | Status | Peran di hackathon |
| --- | --- | --- |
| `josjob` | Sudah ada | Core: Accounts, Orgs, RBAC, Payments, Invitations, Repo, semua migrasi. |
| `josjob_web` | Sudah ada | Satu-satunya Phoenix endpoint: router, controller, plug, LiveView, JSON API, channel. Semua HTTP/web di sini. |
| `josjob_lrn` | Sudah ada | Learning: Section/Course/Class/Enrollment. Dipakai untuk hook kursus. |
| `josjob_doc` | Sudah ada | Dokumen + access grant. Dipakai untuk penyimpanan CV sebagai dokumen. |
| `josjob_ms` | Sudah ada | Leaf media: Cloudflare Stream (VOD) + Realtime (SFU/TURN) + S3. Panggil lewat facade `JosjobMs`, jangan langsung ke provider. |
| `josjob_rag` | Sudah ada | RAG ingestion ke Atomic Server (AtomicClient, Indexer, Extractor + xberg). Dipakai sebagai referensi pola ekstraksi; jangan duplikasi logika ekstraksi di tempat baru tanpa alasan. |
| `josjob_ai` | Minimal, dikembangkan | Agent Jido: `TeacherAssistant` dan `HeadHunter` (TODO matching). **Di sinilah CV extraction + matching tinggal.** Tambah runtime deps di `mix.exs` app ini dan `in_umbrella: true` di app yang memanggilnya. |
| `josjob_job` | **Stub kosong → DIBANGUN** | Domain jobs: Job, Application, Company listing. Ini pekerjaan utama hackathon di backend. |
| `josjob_quiz` | Stub — jangan disentuh | Di luar scope (VISION). |
| `josjob_rt` | Stub — jangan disentuh | Di luar scope (VISION). |

### 2.3 Kontrak dengan frontdev (seam)

Yang harus disepakati bersama frontdev dan ditulis di sini agar tidak berubah
diam-diam:

- Semua endpoint jobs/CV di bawah `/api/*`, Bearer JWT (access ~1 jam,
  refresh ~30 hari rotasi). Respons error memakai bentuk yang konsisten
  dengan API yang sudah ada (`docs/api/auth.md`, `docs/api/learning.md`).
- Analisis CV **asinkron**: upload mengembalikan `202` + `analysis_id` +
  status; hasil diambil via polling endpoint status atau channel notifikasi
  yang sudah ada (`user:notifications:<user_id>`). Jangan blok request HTTP
  menunggu LLM.
- Kontrak status analisis: `queued → processing → done | failed |
  unreadable | partial`. Arti tiap status ada di §4.4.
- Ranking dikembalikan sebagai daftar yang sudah terurut dari server,
  lengkap dengan `match_score`, `missing_skills[]`, dan `explanation`
  per item. Frontend tidak menghitung ulang ranking dari data mentah.
- Lokasi: frontend mengirim jawaban lokasi user ("mau nyari kerja di daerah
  mana") sebagai parameter query/filter biasa — bukan dari IP. Backend tidak
  melakukan IP lookup.

## 3. Auth, RBAC, dan multi-tenancy (sudah ada — pakai, jangan buat baru)

- Auth: Google OAuth (web redirect; `id_token` untuk Flutter via
  `POST /api/auth/google`) atau email + password (Bcrypt, min. 8 karakter).
- Akun: `account_type = :personal` vs `:organization`; organisasi wajib
  email kantor, email gratisan/publik ditolak.
- RBAC **data-driven per-org** (bukan `ash_rbac` code-defined):
  `permissions / roles / role_permissions / memberships / membership_roles`,
  engine `Josjob.Authz` (`permissions_for/ can?/ active_org_id`), plug
  `AssignActiveOrg` + `RequirePermission` + `RequireMember`, org switcher
  (`POST /switch-org`). Role seed: employer, coordinator, teacher, worker,
  graduate (+ `default`, + superuser bypass lintas tenant).
- Permission baru yang dibutuhkan (tambah ke seed + `docs` bila belum ada):
  `jobs:read`, `jobs:post`, `jobs:manage`, `jobs:apply`. Perilaku yang
  diharapkan: graduate/worker boleh `jobs:read` + `jobs:apply`; employer
  boleh `jobs:post` + `jobs:manage` untuk tenant-nya sendiri; superuser
  bypass. **Pilihan untuk backdev** (tanyakan): apakah employer membuat
  lowongan langsung aktif, atau butuh approval admin/superuser dulu?
  Opsi: (a) langsung aktif, (b) butuh approval. Rekomendasi dokumen ini:
  (a) untuk demo.
- Org-scoping: semua query katalog/lowongan harus ter-scope ke organisasi
  user (ikuti pola `docs/api/learning.md`). Jangan bocorkan data lintas
  organisasi.

## 4. CV Analyzer — pipeline

### 4.1 Alur end-to-end

```
Upload PDF (Flutter)
  → POST /api/cv (presigned upload S3-compatible, pola sama seperti dokumen)
  → simpan record CV (lihat §6) + enqueue Oban job
  → 202 { cv_id, analysis_id, status: "queued" }
        │
        ▼  Oban (async, Postgres-backed)
  Ekstraksi teks PDF
  → LLM structured extraction (skill, pengalaman, pendidikan)
  → Embedding (teks CV + tiap lowongan, dihitung sekali — lihat §4.3)
  → Matching + ranking v1 (lihat §5)
  → simpan hasil + provenance (model apa yang dipakai)
  → notifikasi ke user (channel yang sudah ada)
        │
        ▼
  GET /api/cv/:id/analysis → status + hasil
  GET /api/jobs/ranked?cv_id=… → ranking + penjelasan
```

### 4.2 Dua peran AI yang berbeda (jangan dicampur)

| Peran | Tugas | Provider |
| --- | --- | --- |
| **Extraction** | PDF → teks → JSON terstruktur: `skills[]`, `experience[]`, `education[]`, plus `extraction_confidence` | LLM (Gemini, fallback 9Router) |
| **Matching** | Teks CV + deskripsi lowongan → embedding → cosine similarity + skill overlap | Embedding model (Gemini, fallback 9Router bila tersedia) |

### 4.3 Provider: Gemini (primary) + 9Router (fallback)

- **Primary: Gemini API free tier.** Dipakai untuk extraction (LLM) dan
  embedding. Alasan: gratis untuk demo, satu key, sudah diputuskan tim.
- **Fallback: 9Router.** Self-hosted open-source alternatif OpenRouter
  (OpenAI-compatible, BYOK, MIT, port 20128, SQLite). Diverifikasi ada.
- **Akses STRICT localhost.** 9Router di-bind ke `127.0.0.1:20128` di VPS
  yang sama dengan backend. **Hanya backend yang dapat menjangkaunya.**
  Tidak ada rute publik ke 9Router. Dashboard 9Router juga localhost-only
  (diakses via SSH tunnel). Alur persisnya:
  `frontend → backend (proxy) → 9Router → backend (simpan hasil + ranking)
  → frontend`.
- **Backend sebagai proxy:** backend yang memanggil 9Router, bukan frontend.
  Proxy harus: (a) autentikasi user (JWT) sebelum meneruskan, (b) rate
  limit per user, (c) timeout + retry terbatas + circuit breaker supaya satu
  provider lambat tidak menggantung antrean Oban, (d) tidak meneruskan
  prompt bebas dari user — hanya prompt extraction/matching yang sudah
  ditentukan server.
- **Secret:** key Gemini dan key provider di 9Router tinggal di VPS (env),
  tidak pernah di-commit, tidak pernah di-bundle ke Flutter.
- **Fallback berlapis:** Gemini → 9Router → deterministik (keyword/skill
  overlap). Setiap hasil wajib mencatat `provider` dan `model` yang
  memprosesnya (provenance), dan bila skor berasal dari fallback keyword,
  UI harus memberi label jujur (kontrak dengan frontdev).
- **Round-robin 9Router:** banyak free model dari berbagai provider
  di-round-robin untuk menghindari rate limit dan menjaga ketersediaan,
  dengan bayaran **ketidakkonsistenan** — satu CV bisa diproses model mahal
  atau murah, tidak ada yang tahu. Konsekuensi yang harus ditangani:
  skor tidak deterministik; ranking CV yang sama bisa berbeda tiap scan.
  Mitigasi: (a) catat model per analisis, (b) untuk demo pertimbangkan pin
  satu model dan pakai round-robin hanya sebagai fallback saat model utama
  kena rate limit, (c) jangan pakai round-robin untuk re-rank yang sama
  tanpa alasan. **Pilihan untuk backdev** (tanyakan): model mana yang
  di-pin untuk demo? Opsi: (a) satu model Gemini, (b) satu model 9Router
  tertentu, (c) tidak di-pin, round-robin penuh.
- **Risiko 9Router yang dicatat:** provider ToS/kuota tetap berlaku;
  CVE-2026-49352 pernah dilaporkan di 9Router; integrasi gaya MITM untuk
  langganan IDE tertentu harus dicek kebijakannya sebelum dipakai. Gunakan
  key sendiri yang sah (BYOK), bukan "abusing" free tier — dan ungkap
  pemakaian AI + third-party di proposal dan README (aturan handbook).

### 4.4 Status analisis dan CV tidak terbaca

Status yang harus diimplementasikan:

| Status | Arti | Aksi |
| --- | --- | --- |
| `queued` | Menunggu antrean Oban | Tampilkan progress |
| `processing` | Sedang diekstrak/dicocokkan | Tampilkan progress |
| `done` | Selesai, hasil lengkap | Tampilkan ranking |
| `partial` | Teks terekstrak sebagian (misal sebagian field kosong) | Tampilkan hasil + peringatan "sebagian data tidak terbaca, periksa dan koreksi" |
| `unreadable` | CV rusak/tidak terbaca, tidak ada informasi berguna yang terekstrak | Pesan tegas: CV tidak terbaca; user memperbaiki CV dan scan ulang. **Jangan** membuat ranking dari ketiadaan data. |
| `failed` | Provider error setelah retry | Pesan error + tombol coba lagi; jangan tampilkan skor palsu |

Keputusan tim: "kita tidak bisa judging AI-nya" karena modelnya Gemini atau
model 9Router — artinya backend **tidak** mengklaim kebenaran hasil
ekstraksi. Hasil ekstraksi ditampilkan sebagai "hasil AI, periksa dulu" dan
user dapat mengoreksi skill-nya (edit profile) sebelum ranking dipakai.
**Pilihan untuk backdev** (tanyakan): ambang "partial" vs "unreadable"
berdasarkan apa? Opsi: (a) panjang teks terekstrak minimum, (b) jumlah
field terisi minimum, (c) kombinasi keduanya. Rekomendasi dokumen ini: (c).

### 4.5 Penyimpanan hasil

- Simpan: teks hasil ekstraksi (terstruktur), embedding CV (satu per versi
  CV), `match_score` + `missing_skills` + `explanation` per lowongan,
  `provider`, `model`, `analyzed_at`.
- Embedding lowongan dihitung sekali saat lowongan dibuat/diubah, bukan
  tiap kali ranking dibuka.
- Embedding CV dihitung sekali per versi CV (upload baru / CV diubah →
  hitung ulang).

## 5. Ranking

### 5.1 Ranking v1 (MVP — wajib)

Rumus: **match + recency**, deterministik dan bisa dijelaskan.

- `match`: gabungan cosine similarity embedding (CV ↔ deskripsi lowongan)
  dan skill overlap (`skill yang cocok / skill yang diminta`).
- `recency`: lowongan baru mendapat dorongan, lowongan basi kena penalti
  (decay berdasarkan umur lowongan).
- Bobot eksak belum diputuskan — lihat `OPEN-QUESTIONS.md` (Q: bobot v1).
  Apapun bobotnya, harus ditulis di code sebagai konstanta bernama +
  terdokumentasi, dan ranking harus dapat direproduksi dari input yang sama.
- Setiap item ranking wajib mengembalikan: `match_score`, `missing_skills[]`,
  dan `explanation` (kenapa item ini di atas — misal "5/6 skill cocok,
  kurang: SQL"). Ini adalah selling point + hook ke kursus (lihat §5.3).

### 5.2 Ranking v2 (desain dulu — bukan MVP)

Sinyal tambahan: popularitas (views/saves/applies/CTR per user unik, dengan
time decay), affinity user (kategori/industri/lokasi yang pernah
diklik/disave), kualitas listing (lengkap + employer terverifikasi naik).
Kategorisasi: jenis pekerjaan, industri/role family, lokasi, ukuran
perusahaan, level pengalaman (flag "fresh graduate friendly"), rentang gaji,
skill yang diminta. Perlindungan: slot eksplorasi 10–20% untuk lowongan
baru/kurang terekspos (anti rich-get-richer), campuran di luar preferensi
(anti filter bubble), anti-gaming (hitung user unik, bukan hit mentah).

**Pertanyaan terbuka untuk backdev (penting):** v2 ditulis sebagai
**unused code for future use**, atau sebagai **desain di dokumen** saja?
Rekomendasi dokumen ini: **desain saja, jangan tulis dead code** — code yang
tidak dipakai membusuk, membingungkan reviewer repo, dan bisa menggagalkan
CI. V2 diaktifkan hanya bila ada keputusan tim + ada token/waktu. Detail di
`VISION.md` dan `OPEN-QUESTIONS.md`.

### 5.3 Hook ke kursus (selling point)

`missing_skills[]` dari tiap item ranking harus dapat dipetakan ke
course/class JosJob (`josjob_lrn`) — minimal mengembalikan
`course_id`/`class_id` yang relevan bila ada. Ini yang membedakan JosJob
dari job board biasa. Bila tidak ada kursus yang cocok untuk suatu skill,
kembalikan `course: null` — jangan mengarang kursus.

### 5.4 Lokasi

- **IP lookup: DIBUANG.** Tidak ada IP lookup di backend.
- Lokasi berasal dari jawaban user ("mau nyari kerja di daerah mana"),
  dikirim frontend sebagai parameter filter biasa.
- Bobot lokasi: hanya sinyal awal (initial). Bobotnya terdegradasi oleh
  perilaku user (lokasi/pekerjaan/company yang dicari) — detail decay masih
  perlu dikaji (lihat `OPEN-QUESTIONS.md`).
- Bila user tidak menjawab lokasi: ranking tetap jalan tanpa sinyal lokasi.

## 6. Model data (baru + reuse)

### 6.1 Baru — `josjob_job`

| Resource | Field inti | Catatan |
| --- | --- | --- |
| `Job` | `title`, `company_id`/`organization_id`, `location` (teks, dari employer), `employment_type` (full-time/part-time/internship/contract/freelance), `work_mode` (remote/hybrid/onsite), `industry`, `description`, `requirements` (skill list), `salary_band` (opsional), `status` (draft/active/expired), `posted_at` | Org-scoped; hanya employer tenant sendiri yang boleh post/manage. Ikuti pola resource Ash yang sudah ada di `josjob_lrn`. |
| `Application` | `job_id`, `user_id`, `cv_id`, `status`, `applied_at` | Status awal — lihat OPEN-QUESTIONS (Q: set status lamaran). Unik: satu user + satu job + satu CV aktif. |
| `Cv` | `user_id`, `file_url` (S3-compatible, pola dokumen), `extracted` (JSON terstruktur), `embedding_ref`, `status` (§4.4), `provider`, `model`, `analyzed_at` | Simpan sebagai dokumen (`josjob_doc`) bila memungkinkan; jangan duplikasi logika upload dokumen. |
| `CvAnalysis` / hasil | `cv_id`, `job_id`, `match_score`, `missing_skills[]`, `explanation`, `provider`, `model` | Satu baris per pasangan CV–lowongan per versi analisis. |

### 6.2 Reuse — jangan buat baru

- User/Org/RBAC/Payment/Invitation: `josjob` (sudah ada).
- Course/Class/Enrollment: `josjob_lrn` (sudah ada) — untuk hook kursus.
- Dokumen + grant: `josjob_doc` (sudah ada) — untuk file CV.
- VOD/live: `josjob_ms` (sudah ada).
- RAG ingestion: `josjob_rag` (sudah ada) — referensi pola ekstraksi
  (xberg); jangan duplikasi logika ekstraksi tanpa alasan.
- Migrasi: buat dengan `mix ecto.gen.migration`, ikuti konvensi repo.
  Resource Ash mengikuti pola yang sudah ada (lihat `josjob_lrn`).

### 6.3 Data synthetic

- Seed lowongan synthetic untuk dev/demo (sudah diputuskan: synthetic +
  employer-posted). Seed harus jelas berlabel synthetic dan tidak
  mengklaim perusahaan nyata.
- Jangan seed data yang meniru perusahaan nyata dengan nama asli + gaji
  palsu seolah faktual.

## 7. API (kontrak baru)

Semua di bawah `/api`, Bearer JWT, mengikuti gaya `docs/api/*` yang sudah ada.

| Endpoint | Deskripsi |
| --- | --- |
| `GET /api/jobs` | Daftar lowongan + pencarian + filter (jenis, industri, lokasi, work_mode, gaji) + pagination. |
| `GET /api/jobs/:id` | Detail lowongan. |
| `GET /api/jobs/ranked?cv_id=…` | Ranking personal + penjelasan per item. Butuh CV yang sudah `done`/`partial`. |
| `POST /api/jobs` | Employer membuat lowongan (butuh `jobs:post`). |
| `PATCH /api/jobs/:id`, `DELETE /api/jobs/:id` | Employer mengelola lowongan sendiri (`jobs:manage`). |
| `POST /api/cv` | Upload CV (presigned URL, pola dokumen) → `202` + `analysis_id`. |
| `GET /api/cv/:id/analysis` | Status + hasil analisis (§4.4). |
| `DELETE /api/cv/:id` | Hapus CV — harus menghapus file, teks ekstraksi, dan embedding (GDPR). |
| `POST /api/jobs/:id/apply` | Apply dengan `cv_id` (butuh `jobs:apply`). |
| `GET /api/me/applications` | Riwayat lamaran + status. |
| `GET /api/employer/applications` | Daftar pelamar untuk lowongan miliknya. |
| `PATCH /api/applications/:id/status` | Employer mengubah status lamaran. |

**Pilihan untuk backdev** (tanyakan): set status lamaran apa saja? Opsi:
(a) Pending/Reviewed/Accepted/Rejected, (b) tambah Interview dan Offer.
Rekomendasi dokumen ini: (b) bila mudah, karena alur rekrutmen nyata
membutuhkannya — tapi (a) cukup untuk demo. Juga: apakah kandidat melamar
langsung di platform (diputuskan: ya, in-platform) dan apakah employer
membuat lowongan langsung aktif (lihat §3).

## 8. Keamanan dan privasi (backend)

- **Standar web2.** Delegasi ke backdev/frontdev masing-masing, tapi seam
  (auth, CORS, rate limit, secret) harus disepakati — lihat §2.3.
- Secret hanya di env VPS; tidak pernah di-commit; tidak pernah ke frontend.
- Rate limit per user untuk endpoint AI (upload + analisis + ranking).
- Validasi input di semua endpoint; jangan pakai `String.to_atom/1` pada
  input user (house rules).
- **GDPR (keputusan tim):** lawful basis = consent eksplisit (checkbox di
  frontend sebelum CV diproses). Data yang dikirim ke pihak ketiga (Gemini /
  provider di 9Router) harus diungkap di Privacy Policy. Hak hapus: DELETE
  CV harus benar-benar menghapus file + teks + embedding. Tidak ada
  penghapusan otomatis — CV disimpan selama user tidak menghapusnya (keputusan
  tim, untuk reuse saat apply). Retensi lain (log, analisis lama) perlu
  diputuskan — lihat OPEN-QUESTIONS.
- 9Router: bind localhost saja; dashboard localhost-only; key provider
  disimpan di 9Router di VPS, bukan di repo.
- Jangan log isi CV mentah atau teks hasil ekstraksi lengkap di log aplikasi.

## 9. Pengujian

- **Manual test untuk full flag** (dengan model asli) — tanggung jawab tim,
  bukan CI.
- **Tanpa model Gemini di CI/CD** (hindari rate limit). AI di CI diganti
  mock/stub dengan respons yang sudah ditentukan.
- Test Oban job: antrean, retry, timeout, dan status `unreadable`/`partial`/
  `failed` harus ter-cover.
- Test ranking v1: deterministik — input sama → output sama; uji dengan
  dataset synthetic kecil (CV × lowongan) dan periksa urutannya masuk akal.
- Ikuti house rules test: `start_supervised!/1`, hindari `Process.sleep/1`,
  dan `mix precommit` harus hijau sebelum merge.

## 10. Kriteria penerimaan (backend, dapat diuji)

- [ ] `POST /api/cv` dengan PDF valid → `202` + `analysis_id`; hasil
      `done` berisi skill/pengalaman/pendidikan terstruktur.
- [ ] PDF rusak/tidak terbaca → status `unreadable` + tidak ada ranking
      yang dibuat dari ketiadaan data.
- [ ] `GET /api/jobs/ranked?cv_id=…` mengembalikan daftar terurut + tiap
      item punya `match_score`, `missing_skills[]`, dan `explanation`.
- [ ] `missing_skills[]` yang punya kursus mengembalikan referensi
      course/class; yang tidak punya mengembalikan `null` (tidak mengarang).
- [ ] Gemini down → fallback 9Router jalan; keduanya down → fallback
      keyword jalan + hasil berlabel jujur.
- [ ] `DELETE /api/cv/:id` menghapus file + teks + embedding (verifikasi
      dengan GET setelahnya → 404).
- [ ] Tanpa JWT → 401; user dari org lain tidak dapat melihat/mengubah
      lowongan tenant lain.
- [ ] 9Router tidak dapat dijangkau dari luar VPS (hanya `127.0.0.1`).
- [ ] CI hijau tanpa memanggil Gemini asli.

## 11. Dependensi dan risiko (backend)

- VPS + domain + Cloudflare (nanti); key Gemini; key provider di 9Router.
- Ketersediaan model gratis di 9Router dapat berubah sewaktu-waktu (provider
  dapat menarik free tier) — mitigasi: fallback berlapis + provenance.
- Round-robin → skor tidak deterministik (lihat §4.3).
- Originality: pekerjaan baru selama lomba adalah `josjob_job` +
  `josjob_ai` (CV/matching) + integrasi; JosJob yang sudah ada harus
  diatribusi, bukan diklaim sebagai karya baru.
