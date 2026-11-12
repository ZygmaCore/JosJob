# PRD — JosJob (STACK 2026, GDGoC ITB)

> **Status:** Draft v2 (oneshot) — 11 November 2026. Menggantikan PRD arsitektur v1
> (13 halaman, 10 November 2026) yang dibuat sebelum koreksi-koreksi di
> `NOTES.md`. Dokumen ini adalah acuan bersama tim **admin123** untuk keputusan
> produk, desain, arsitektur, implementasi, dan pengujian.
>
> **Bahasa:** Dokumen kerja tim ini ditulis dalam Bahasa Indonesia. Abstrak dan
> semua submission lomba tetap dalam Bahasa Inggris (aturan handbook).
>
> **Cara membaca:** Dokumen ini adalah PRD level tim. Detail per scope ada di
> `backdev/PRD.md` dan `frontdev/PRD.md`. Pertanyaan yang butuh diputuskan
> bersama ada di `DECISIONS.md`. Metrik ada di `METRICS.md` (masih bahan
> diskusi team meet). Konteks lengkap dan asal setiap keputusan ada di
> `NOTES.md`.
>
> **Aturan penulisan PRD ini:** klaim tentang apa yang sudah ada di repo harus
> bisa ditelusur ke code. Yang masih rencana ditulis sebagai rencana, bukan
> sebagai fitur jadi. Angka dan target tidak dikarang — lihat `METRICS.md`.

## 1. Tujuan

Menghasilkan satu platform job seeker untuk fresh graduate yang menutup loop
**Match → Gap → Learn → Re-match**:

1. Graduate mengupload CV.
2. AI mengekstrak skill/pengalaman/pendidikan dari CV dan memberi **ranking
   perusahaan/lowongan yang cocok**, lengkap dengan penjelasan skornya.
3. Skill yang hilang dijelaskan dan dihubungkan langsung ke **learning path**
   (kursus/kelas) di platform yang sama.
4. Setelah belajar, graduate menjalankan ulang analisis dan melihat ranking
   yang diperbarui, lalu melamar.

PRD ini menjadi acuan bersama untuk keputusan produk, desain, arsitektur,
implementasi, dan pengujian — sesuai rincian tugas di Notion.

## 2. Konteks

### 2.1 Produk dan tim

| Item | Isi |
| --- | --- |
| Nama produk | **JosJob** (final, sesuai abstrak) |
| Nama tim | **admin123** (final — memang itu namanya) |
| Anggota | Fathan Akram (Leader), Alhikam Dirga, Dimas Sakti, Juang Zebua |
| Peran kerja | **frontdev** 1 orang, **backdev** 1 orang, dan user (penulis dokumen) dapat intervensi/membantu di kedua scope. Masing-masing punya AI sendiri. |
| Case lomba | Case 1: Smarter Campus and Learning — "How might we help students learn, collaborate, and access campus opportunities more effectively?" |
| Lomba | STACK 2026, GDGoC ITB (Solution Technology Arena for Coding & Knowledge) |
| Tema | "Agent of the Ocean: Vibing Beyond the Code" — proyek **tidak wajib** soal kelautan, AI agent **tidak wajib** |

### 2.2 Fondasi: JosJob (renovasi, bukan bangun ulang)

Project lomba ini ditaruh **ON TOP dari JosJob yang sudah ada** — singkatnya
JosJob direnovasi. JosJob adalah project lama teman tim:

- Repo: `https://github.com/ZygmaCore/job-seeker-ai` (publik, 1 commit init
  `11e9529`, 9 November 2026, 823 file).
- Nama di repo: **JosJob / JosJob** — "Online Learning & AI Job
  Placement".
- Stack: Elixir/Phoenix 1.8 + Ash Framework (umbrella, 10 apps, satu rilis OTP
  `josjob`) + Flutter Web (satu aplikasi unified).
- Yang **sudah jalan** (terverifikasi di code): learning terstruktur
  `Section → Course → Class → Enrollment`, katalog org-scoped, enroll gratis
  atau berbayar Stripe, dokumen sebagai materi + sharing per-grant, VOD HLS
  via Cloudflare Stream, live class WebRTC (Cloudflare Realtime SFU + TURN),
  Google OAuth + email/password + JWT, RBAC per-org data-driven, onboarding
  wajib, RAG ingestion per-course ke Atomic Server, offline-first Flutter
  (Drift + SQLite outbox), CMS LiveView + AshAdmin.
- Yang **belum jalan** (stub / UI-only, jangan diklaim sebagai fitur jadi):
  backend jobs (`apps/josjob_job` stub kosong), quiz (`josjob_quiz` stub),
  realtime (`josjob_rt` stub); Jobs board Flutter hanya UI dengan 6 lowongan
  hard-coded; agent `HeadHunter`/`TeacherAssistant` (Jido) minimal dengan TODO
  skill-matching; RAG Q&A streaming, sertifikat, dan FCM hanya ada di
  `docs/01–10` sebagai desain.

**Keputusan arsitektur yang sudah final:** stack microservices polyglot
(Go/TypeScript/Python, Kong, RabbitMQ) dari PRD awal **gugur**. Yang dipakai
adalah stack JosJob (Elixir/Phoenix + Ash + Flutter, modular monolith).
Abstrak menyebut "monorepo of independently deployable microservices" —
wording itu milik abstrak sebagai dokumen submission; code yang berlaku untuk
build adalah monolith satu rilis OTP. Perbedaan ini dicatat sebagai ketegangan
yang diketahui, bukan disembunyikan (lihat `NOTES.md`).

### 2.3 Data lowongan

- **Scraping Glints/Upwork/board lain: BATAL.** Itu plan lama saja.
- Plan terbaru mengacu ke abstrak + ringkasan JosJob: lowongan berasal dari
  **employer yang memposting sendiri** dan **data synthetic** selama
  development/demo (sesuai abstrak: "development uses synthetic data").
- Semua data demo harus diidentifikasi dengan jelas sebagai synthetic
  (aturan handbook).

## 3. Masalah, pengguna, dan bukti

### 3.1 Masalah

Fresh graduate di Indonesia sulit mengubah ijazah menjadi pekerjaan pertama.
Lowongan tersebar di banyak platform, graduate jarang tahu perusahaan mana
yang cocok dengan skill-nya, dan menutup skill gap berarti keluar dari
pencarian kerja untuk mencari kursus di tempat lain — tanpa hubungan antara
apa yang diminta employer dan apa yang dipelajari graduate.

### 3.2 Pengguna sasaran

| Pengguna | Kebutuhan inti |
| --- | --- |
| **Fresh graduate / mahasiswa tingkat akhir** (pengguna utama) | Tahu perusahaan/lowongan apa yang cocok dengan CV-nya, tahu skill apa yang kurang, dan bisa menutup gap itu tanpa pindah platform. |
| **Employer** | Memposting dan mengelola lowongan, menerima lamaran, mengubah status lamaran. |
| **Teacher / coordinator (institusi)** | Mengelola course/class/member untuk tenant-nya, mengampu kelas. |
| **Superuser / admin platform** | Mengelola users, organizations, skills, roles/permissions lintas tenant. |

### 3.3 Bukti

- Data BPS Sakernas (Mei 2026) yang dikutip abstrak: sekitar 1,03 juta
  penganggur berpendidikan D4–S3, atau 14,31% dari semua penganggur. **Status:
  BELUM TERVERIFIKASI ke rilis resmi BPS — wajib diverifikasi sebelum dipakai
  di dokumen resmi manapun.** Abstrak yang diupload masih memuat baris
  disclaimer bahwa nama/angka/data di dalamnya diciptakan untuk contoh gaya;
  baris itu harus dihapus sebelum submission.
- Bukti dari repo: learning platform JosJob sudah berjalan (lihat §2.2).
  Tidak ada data riset pengguna/wawancara, analitik produk, atau angka dampak
  lain di repo — semuanya harus ditandai sebagai "perlu diisi tim" bila ingin
  dicantumkan.

## 4. Tujuan, non-goals, dan scope MVP

### 4.1 Tujuan produk

1. Graduate mendapat ranking perusahaan/lowongan yang cocok dari CV-nya dalam
   hitungan menit, dengan penjelasan tiap skor.
2. Setiap skill yang hilang terhubung ke learning path yang bisa langsung
   diambil.
3. Setelah belajar, ranking dapat dijalankan ulang dan menunjukkan perubahan.
4. Employer dapat memposting lowongan dan mengelola lamaran sampai status
   akhir.

### 4.2 Non-goals (eksplisit — di luar scope hackathon)

- Scraping lowongan dari Glints/Upwork/board lain.
- Aplikasi mobile native terpisah (mobile = Flutter yang sama, direnovasi;
  fokus demo adalah web).
- Monetisasi/premium untuk sisi job (graduate tidak membayar untuk
  match/apply). Monetisasi ada di sisi **pembelajaran/course** (lihat §7).
- AI untuk recruiter (screening otomatis lamaran masuk) — CV Analyzer hanya
  untuk kandidat di v1.
- Pembayaran untuk posting lowongan.
- Quiz bergating + sertifikat, RAG Q&A streaming, FCM push — semuanya desain
  di docs, bukan scope hackathon (lihat `backdev/VISION.md` dan
  `frontdev/VISION.md`).

### 4.3 Scope MVP (yang harus selesai end-to-end)

Alur MVP, sesuai plan awal tim:

> Buka website → lihat daftar pekerjaan → lihat detail → login/register →
> upload CV → lihat ranking + penjelasan → (opsional) ambil kursus untuk skill
> yang hilang → apply → employer menerima lamaran → employer mengubah status
> → kandidat melihat hasilnya.

Setelah alur itu stabil, AI CV Analyzer adalah pembeda utamanya. Satu core
flow yang lengkap (minimal) wajib jalan untuk Final Day: **upload CV →
ranking + penjelasan → apply**.

### 4.4 Skenario penggunaan utama

1. **Graduate baru, tanpa CV yang rapi.** Landing → daftar pekerjaan
   (ranking umum) → detail → register/login → upload CV → analisis berjalan
   asinkron → ranking personal + penjelasan → klik skill hilang → kursus →
   enroll → jalankan ulang analisis → apply.
2. **Graduate yang sudah punya CV tersimpan.** Login → CV lama dipakai ulang
   untuk apply ke lowongan lain tanpa upload ulang.
3. **Employer.** Register sebagai organisasi → posting lowongan → lihat daftar
   pelamar → ubah status lamaran → kandidat melihat status.
4. **Teacher.** Melihat class yang diampu → mengelola dokumen/materi →
   memulai sesi live.

### 4.5 Edge case (wajib ditangani, bukan diabaikan)

- CV rusak/tidak terbaca: sampaikan tegas bahwa CV tidak terbaca dan tidak
  ada informasi berguna yang terekstrak; user memperbaiki CV dan scan ulang.
  Tidak ada penilaian terhadap AI-nya — model yang dipakai adalah Gemini
  atau model 9Router. Bedakan status "tidak terbaca sama sekali" vs "terbaca
  sebagian" (lihat `backdev/PRD.md` §4 dan `frontdev/PRD.md` §5).
- Tidak ada lowongan yang cocok: tampilkan pesan jujur + saran (longgarkan
  filter/lokasi, lengkapi skill) — jangan tampilkan ranking kosong tanpa
  penjelasan.
- Gemini dan 9Router dua-duanya down: fallback deterministik (keyword/skill
  overlap) dengan label jujur di UI bahwa skor bersifat sementara.
- User menolak berbagi lokasi: ranking tetap jalan tanpa sinyal lokasi.
- Lowongan kedaluwarsa / class penuh saat enroll dari hook kursus: beri pesan
  yang jelas dan tawarkan alternatif.
- Sesi/token kedaluwarsa di tengah alur: refresh token lalu ulangi request,
  jangan buang draft/apply yang sedang berjalan.

## 5. Kebutuhan fungsional (ringkas, prioritas)

Prioritas: **M** = Must (MVP), **S** = Should (bila waktu memungkinkan),
**C** = Could (parkir). Detail per requirement ada di `backdev/PRD.md` dan
`frontdev/PRD.md` — di sini hanya peta level tim.

| # | Kebutuhan | Prioritas | Pemilik |
| --- | --- | --- | --- |
| F1 | Landing page hasil renovasi (atas ala Upwork: pengenalan + search; bawah ala Glints: ranking) | M | frontdev |
| F2 | Daftar pekerjaan + pencarian + filter + detail pekerjaan | M | frontdev + backdev |
| F3 | Auth: Google OAuth + email/password, JWT + refresh, RBAC per-org | M (sudah ada) | backdev |
| F4 | Profil lengkap yang bisa dikustomisasi + edit skill | M | frontdev + backdev |
| F5 | Upload CV (PDF), simpan, hapus, reuse untuk apply | M | frontdev + backdev |
| F6 | AI CV Analyzer: ekstraksi terstruktur (skill, pengalaman, pendidikan) | M | backdev |
| F7 | Ranking perusahaan/lowongan + penjelasan skor + skill yang hilang | M | backdev + frontdev |
| F8 | Hook skill hilang → learning path (kursus/kelas JosJob) | M | frontdev + backdev |
| F9 | Apply lamaran + riwayat lamaran + status lamaran | M | frontdev + backdev |
| F10 | Employer: posting/kelola lowongan, lihat pelamar, ubah status | M | backdev + frontdev |
| F11 | Learning: katalog, enroll class (gratis/berbayar Stripe), materi, VOD, live | M (sudah ada) | — (renovasi) |
| F12 | Consent checkbox pemrosesan CV + halaman Privacy Policy + ToS | M | frontdev + backdev |
| F13 | Ranking dinamis v2 (popularitas, affinity, eksplorasi) | S (desain dulu) | backdev + frontdev |
| F14 | Tanya lokasi sekali ("mau nyari kerja di daerah mana"), simpan lokal | M | frontdev |
| F15 | Ranking v1: match + recency (deterministik, bisa dijelaskan) | M | backdev |
| F16 | Admin CMS + undangan teacher | S (sudah ada) | — (renovasi) |

## 6. Kebutuhan nonfungsional

| Area | Kebutuhan |
| --- | --- |
| Keamanan | Standar web2. Secret hanya di server/VPS, tidak pernah di-bundle ke Flutter. JWT access ~1 jam, refresh ~30 hari dengan rotasi. RBAC per-org data-driven (sudah ada). Rate limit per user untuk endpoint AI. 9Router STRICT localhost (hanya backend di host yang sama yang dapat menjangkaunya). Detail dan pembagian ke backdev/frontdev ada di `backdev/PRD.md` §8 dan `frontdev/PRD.md` §8. |
| Privasi | Patuh GDPR (keputusan tim). Consent eksplisit sebelum CV diproses (checkbox). CV **tidak** dihapus otomatis setelah ekstraksi — user boleh hapus atau biarkan; CV yang disimpan dapat dipakai ulang untuk apply. "Hapus" harus menghapus file, teks hasil ekstraksi, dan embedding-nya. CV dikirim ke pihak ketiga (Gemini / provider di 9Router) — harus diungkap di Privacy Policy. Lokasi hanya dari jawaban user, disimpan di local browser saja, bukan di server. IP lookup: DIBUANG. |
| Performa | Analisis CV berjalan asinkron (Oban) — user tidak menunggu di halaman upload. Embedding CV dihitung sekali per versi CV; embedding lowongan sekali saat dibuat. Target angka performa belum disepakati — lihat `METRICS.md`. |
| Reliabilitas | Fallback berlapis: Gemini → 9Router (round-robin model gratis) → keyword/skill overlap. Kegagalan satu provider tidak boleh menggantung antrean. |
| Deployment | VPS (sudah dites build + deploy JosJob oleh user, jalan tanpa user — cukup untuk demo). Domain sudah ada. Cloudflare dipakai nanti (bareng streaming yang sudah ada di JosJob). Bila menang dan go public, arsitektur deployment dimatangkan lagi. |
| Keterujian | Test manual untuk full flag (dengan model asli). **Tanpa** model Gemini di CI/CD (hindari rate limit). AI di CI diganti mock/stub. Lihat `backdev/PRD.md` §9. |
| Aksesibilitas & UX | Ranking harus bisa dijelaskan tiap itemnya. Semua state (loading, kosong, error, tidak terbaca) punya pesan yang jelas. |

## 7. Model bisnis

Monetisasi ada di sisi **pembelajaran/course** — kompetensi pengguna mengikuti
pekerjaan yang diimpikan. Mekanisme ini sudah ada di JosJob: course berbayar
via `price_cents` + Stripe (PaymentIntent/Checkout/Subscription). Sisi job
(match, ranking, apply) gratis untuk graduate. Tidak ada angka harga atau
pendapatan di dokumen ini — tidak ada datanya di repo.

## 8. Arsitektur (ringkas)

```
Flutter Web (renovasi, apps/josjob_fe) — landing, auth, onboarding,
dashboard Learn | Jobs, jobs, CV upload, apply, kursus
        │
        ▼  HTTPS + Bearer JWT
Phoenix 1.8 API + LiveView (apps/josjob_web, :4000) — /api/*, /socket
        │
        ▼
Domain Ash (apps/josjob, josjob_lrn, josjob_doc, josjob_ms, josjob_rag)
  ├─ josjob_job — BARU (hackathon): Job, Application, Company listing
  ├─ josjob_ai  — BARU (hackathon): CV extraction + matching (Jido agents)
  └─ josjob_lrn / josjob_doc / josjob_ms — sudah ada (renovasi)
        │
        ▼
ParadeDB (PostgreSQL) :5438 + Cloudflare Stream/Realtime + S3-compatible
+ Stripe + Google OAuth + SMTP Zoho + Oban
        │
  AI (di VPS, localhost-only): Gemini API (primary) → 9Router (fallback,
  bind 127.0.0.1:20128, hanya backend yang dapat menjangkau)
```

Keputusan: **modular monolith**, satu rilis OTP `josjob`, deploy via Docker
Compose di VPS. Bukan microservices yang di-deploy terpisah. Detail ada di
`backdev/PRD.md` §2. Diagram alur AI ada di `backdev/PRD.md` §4.

## 9. AI — CV Analyzer dan ranking (ringkas)

- **Dua peran yang berbeda:** (a) *extraction* — LLM membaca PDF CV menjadi
  skill/pengalaman/pendidikan terstruktur; (b) *matching* — embedding model
  + skill overlap memberi skor kecocokan CV ↔ lowongan.
- **Provider:** Gemini API free tier sebagai primary (embed + LLM). Fallback
  ke **9Router** (self-hosted, OpenAI-compatible, BYOK, MIT, port 20128) —
  diverifikasi ada. 9Router STRICT localhost; backend bertindak sebagai proxy.
- **Round-robin 9Router:** banyak free model dari berbagai provider
  di-round-robin untuk menghindari rate limit dan menjaga ketersediaan,
  dengan bayaran **ketidakkonsistenan** (satu CV bisa diproses model mahal
  atau murah, tidak ada yang tahu). Setiap hasil analisis wajib mencatat
  model mana yang memprosesnya (provenance). Untuk demo, pertimbangkan pin
  satu model; round-robin hanya sebagai fallback.
- **Ranking v1 (MVP):** match + recency — deterministik dan bisa dijelaskan.
  **Ranking v2 (desain dulu):** tambah popularitas, affinity, eksplorasi
  (slot 10–20% untuk lowongan baru/kurang terekspos), anti filter-bubble dan
  anti rich-get-richer. V2 ditulis sebagai desain di PRD; apakah v2 ditulis
  sebagai unused code masih **pertanyaan terbuka untuk backdev** (lihat
  `backdev/OPEN-QUESTIONS.md` — rekomendasi dokumen ini: jangan tulis dead
  code, tulis desainnya).
- **Kategorisasi ranking:** jenis pekerjaan (full-time, part-time, internship,
  contract, freelance, remote/hybrid/onsite), industri/role family, lokasi
  (negara → region/provinsi → kota + remote), ukuran perusahaan, level
  pengalaman (flag "fresh graduate friendly"), rentang gaji, skill yang
  diminta.
- Detail lengkap: `backdev/PRD.md` §4–§5.

## 10. Data

- Lowongan: synthetic (dev/demo) + employer-posted. Field inti: judul,
  perusahaan, lokasi, jenis pekerjaan, industri, deskripsi, requirements
  (skill), gaji (band), status, tanggal.
- CV: file PDF + teks hasil ekstraksi + skill terstruktur + embedding (satu
  per versi CV). Disimpan selama user tidak menghapusnya; dapat dipakai ulang
  untuk apply.
- Skill taxonomy: pakai master data JosJob yang sudah ada
  (industries/skills/professions) sebagai dasar.
- Model data lengkap: `backdev/PRD.md` §6.

## 11. Metrik keberhasilan

**Belum ada metrik yang disepakati.** Ini gap terbesar dan sengaja tidak
diisi dengan angka karangan. Kandidat metrik + pertanyaan diskusi ada di
`METRICS.md` (bahan team meet berikutnya). PRD ini belum memenuhi kriteria
"metrik tidak mengandung target yang belum disepakati" — dan itu dinyatakan
dengan jujur di sini, bukan ditutup-tutupi.

## 12. Kriteria penerimaan (level tim)

- [ ] Satu core flow lengkap jalan end-to-end: upload CV → ranking +
      penjelasan → apply (wajib untuk Final Day).
- [ ] Ranking tiap item dapat dijelaskan (skor + skill yang hilang).
- [ ] CV tidak terbaca menghasilkan pesan tegas + jalan keluar (perbaiki dan
      scan ulang), bukan ranking kosong.
- [ ] Fallback AI bekerja saat Gemini down; UI memberi label jujur saat skor
      berasal dari fallback keyword.
- [ ] Consent checkbox ada sebelum CV diproses; Privacy Policy + ToS tersedia.
- [ ] Employer dapat posting lowongan dan mengubah status lamaran; kandidat
      melihat statusnya.
- [ ] Demo memakai data synthetic yang diidentifikasi dengan jelas.
- [ ] Kriteria penerimaan per fitur (yang dapat diuji) ada di
      `backdev/PRD.md` §10 dan `frontdev/PRD.md` §10.
- [ ] PRD ini direview dan disetujui oleh user + 1 orang lagi (lihat §14).

## 13. Asumsi, batasan, dependensi, risiko

| Jenis | Isi |
| --- | --- |
| Asumsi | Kuota Gemini free tier cukup untuk demo (puluhan CV). Satu model embedding + satu LLM cukup untuk v1. VPS yang sudah dites cukup untuk demo tanpa user. |
| Batasan | Gemini free tier: rate limit, tanpa SLA. 9Router: butuh key provider sendiri; CVE-2026-49352 pernah dilaporkan di 9Router; integrasi gaya MITM untuk langganan IDE tertentu harus dicek kebijakannya. Handbook: proyek harus baru untuk STACK 2026 — JosJob adalah basis yang sudah ada dan harus diatribusi, bukan disajikan sebagai karya orisinil tim. |
| Dependensi | VPS + domain + Cloudflare (nanti); key Gemini; key provider di 9Router; repo JosJob; keputusan backdev/frontdev yang masih terbuka (lihat `DECISIONS.md`). |
| Risiko | **Originality** (terbesar dari sisi lomba): reuse JosJob vs aturan "existing projects may not be resubmitted/renamed/repackaged" — mitigasi: klaim hanya pekerjaan baru selama lomba, atribusi JosJob, Declaration of Originality di semifinal, riwayat dev yang bisa diverifikasi. **Konsistensi skor** dari round-robin free model. **Rate limit** Gemini di tengah demo. **Angka BPS** belum terverifikasi. **Deadline**: semifinal 30 Nov (proposal + video), Final Day 16 Des. |
| Pertanyaan terbuka | Lihat `DECISIONS.md` (level tim), `backdev/OPEN-QUESTIONS.md`, `frontdev/OPEN-QUESTIONS.md`. |

## 14. Timeline lomba (23:59 WIB)

| Tanggal | Tahap |
| --- | --- |
| 20 Okt–7 Nov 2026 | Registrasi (diperpanjang) |
| 10 Nov 2026 | Preliminary submission — abstrak + bukti twibbon (sudah lewat saat PRD ini ditulis; status submission perlu dikonfirmasi) |
| 18 Nov 2026 | Pengumuman semifinal |
| 30 Nov 2026 | Semifinal submission — proposal (maks 10 halaman) + video (maks 2 menit) |
| 7 Des 2026 | Pengumuman Top 10 |
| 7–16 Des 2026 | Product improvement |
| 16 Des 2026 | Final Day (rencana offline, Bandung) |

## 15. Review dan persetujuan

- Reviewer PRD ini: user + 1 orang lagi (sesuai keputusan tim).
- PRD arsitektur v1 (10 Nov 2026) sudah tidak berlaku sebagai acuan utama —
  digantikan dokumen ini + folder `backdev/` dan `frontdev/`.
- Perubahan setelah review dicatat di `DECISIONS.md`.

## 16. Referensi

- Abstrak final JosJob (PDF) — sumber paling benar bila ada info yang rancu.
- Handbook STACK 2026 (GDGoC ITB).
- Repo `ZygmaCore/job-seeker-ai` — `README.md`, `docs/ringkasan-project-untuk-abstrak.md`,
  `docs/01–10`, `docs/api/*`, `docs/specs/*`, `CLAUDE.md`.
- Plan awal tim (`plan__sebelum_penambahan_stelar.md`) dan PRD awal
  (`PRD_awal__sebelum_penambahan_josjob.md`) — keduanya **sebelum**
  penambahan JosJob; plan scraping dan stack microservices-nya sudah batal.
- `NOTES.md` di folder ini — catatan konteks dan intent lengkap.
