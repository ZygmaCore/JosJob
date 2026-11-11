# NOTES — Catatan dan pengetahuan (konteks + intent)

> Dokumen ini adalah catatan kecil yang merangkum **semua konteks dan intent
> user** yang menjadi dasar PRD oneshot ini. Tujuannya: bila ada yang membaca
> PRD ini tanpa mengikuti percakapan, mereka tetap paham kenapa setiap
> keputusan diambil, dari mana asalnya, dan apa yang masih belum diputuskan.
>
> **Aturan chat ini:** side chat ini khusus hackathon, terpisah — konteksnya
> tidak dicampur dengan chat lain, dan tidak dibawa ke chat lain.

## 1. Siapa dan apa

- **User** (penulis dokumen ini dari sisi tim): bertugas menulis
  abstrak/dokumen (Bahasa Inggris) untuk tim **admin123** di hackathon
  **STACK 2026 (GDGoC ITB)**. User dapat intervensi/membantu di scope
  backdev maupun frontdev.
- **Tim:** Fathan Akram (Leader), Alhikam Dirga, Dimas Sakti, Juang Zebua.
  **frontdev 1 orang, backdev 1 orang** (koreksi 11 Nov 2026 — sempat
  tercatat keliru sebagai 2 backdev). Masing-masing punya AI sendiri.
- **Produk:** **JosJob** — platform job seeker untuk fresh graduate, dengan
  CV analyzer + ranking, dibangun ON TOP dari project lama teman tim
  (**Stellar**), plus pengasah skill (learning) sebagai nilai jual.
- **Peran asisten di chat ini:** menulis PRD (bukan menulis code).
  PRD arsitektur v1 (13 halaman, 10 Nov 2026) sudah pernah dibuat dan
  dibagikan; dokumen oneshot ini (11 Nov 2026) menggantikannya sebagai
  acuan utama karena sudah memasukkan semua koreksi sesudahnya.

## 2. Kronologi percakapan (ringkas)

1. **10 Nov, 10:43** — User menetapkan side chat ini khusus hackathon,
   terisolasi dari chat lain.
2. **10 Nov, 10:48** — User meminta digest repo
   `ZygmaCore/job-seeker-ai` dan penulisan Arsitektur PRD untuk tim (tanpa
   code). Repo ternyata project lama yang fokusnya hanya course belajar.
3. **10 Nov, 10:50–10:54** — Digest selesai; PRD arsitektur v1 (13 halaman,
   Bahasa Indonesia) dibuat dan dibagikan. Pembagian jujur: learning sudah
   jalan, jobs/quiz/realtime masih stub/UI-only.
4. **10 Nov, 10:56** — User menambahkan prompt + planning saat menulis
   abstrak (plan awal tim sebelum Stellar) + 3 file: plan awal, PRD awal,
   dan ringkasan Stellar. Lalu user mengoreksi: "digest aja, belum
   ngapa-ngapain" — build abstrak English yang sempat jalan langsung
   **di-stop** dan dibatalkan.
5. **10 Nov, 11:04** — User menambahkan Handbook STACK 2026 + 3 koreksi:
   stack conflict selesai (ON TOP Stellar = renovasi), scraping batal
   (plan lama), abstrak final dan paling benar bila ada info rancu.
6. **11 Nov, 07:36** — User mulai memikirkan PRD: ide dikirim satu per
   satu, dicatat di konteks + diberi saran, **BELUM MENULIS** — oneshot
   nanti saat plan matang. 4 ide pertama: (1) RAG CV pakai Gemini free
   tier + fallback 9Router; (2) landing fusi Upwork (atas) + Glints
   (bawah); (3) ranking dinamis ala sosmed; (4) IndexedDB untuk ranking.
7. **11 Nov, 07:57–07:58** — Klarifikasi istilah: "backend"/"frontend"
   maksudnya **orangnya**, selanjutnya disebut **backdev** dan
   **frontdev**.
8. **11 Nov, 08:10** — Koreksi: masing-masing 1 orang (bukan 2 backdev).
   User menerima catatan + reasoning asisten sebagai sudah align dengan
   intensinya, lalu bertanya apakah ada catatan kecil atau hanya in-memory.
   Jawaban: ada file catatan khusus side chat ini
   (`~/side-chats/8245dfe4-92c3-48bd-acad-ee4699bcab1c/MEMORY.md`).
9. **11 Nov, 08:19** — User mengirim rincian tugasnya di Notion (tujuan
   PRD, ruang lingkup, kriteria selesai, dependensi) dan bertanya "apalagi
   yang belum ya?" — dijawab dengan gap analysis (gap terbesar: metrik).
10. **11 Nov, 08:41** — User menjawab 9 gap satu per satu (monetisasi
    course, CV rusak, keamanan/privasi/GDPR/VPS/Cloudflare, 9Router strict
    localhost + lokasi tanya-sekali, metrik sebagai .md terpisah, testing
    manual + round-robin, birokrasi skip, reviewer user + 1 orang,
    dependensi skip).
11. **11 Nov, 08:47** — User meminta oneshot: tulis PRD.md di folder PRD
    dalam repo + subfolder backdev/frontdev dengan PRD.md scoped +
    VISION.md, boleh tambah file .md lain yang penting, yang scoped masuk
    folder masing-masing, yang perlu dibahas tim di root PRD, plus file
    catatan ini.

## 3. Intent user (yang harus dijaga)

- **Digest dulu, tulis belakangan.** Bila user bilang "digest aja", semua
  build deliverable harus langsung di-stop. Deliverable hanya dimulai dari
  permintaan eksplisit yang baru.
- **PRD yang kaya konteks + pilihan.** File `.md` untuk backdev/frontdev
  harus memberi **pilihan**, supaya AI mereka bisa menanyakan konfirmasi ke
  mereka saat development — bukan instruksi kaku satu jalur.
- **Jujur soal status.** Yang sudah ada vs desain vs stub vs baru-hackathon
  harus dilabeli dengan jujur. Fitur rencana tidak boleh ditulis seolah
  sudah jadi. Angka tidak boleh dikarang.
- **Abstrak adalah sumber paling benar** bila ada info yang rancu.
- **Konteks tidak keracun.** Side chat ini terisolasi; jangan campur dengan
  chat lain.

## 4. Keputusan kunci + asalnya

| Keputusan | Asal |
| --- | --- |
| Renovasi Stellar (ON TOP), bukan bangun ulang | User, 10 Nov |
| Stack microservices PRD awal gugur; pakai Elixir/Phoenix + Ash + Flutter | User + verifikasi repo, 10 Nov |
| Scraping batal; data synthetic + employer-posted | User, 10 Nov |
| Gemini free tier primary, 9Router fallback | User, 11 Nov |
| 9Router strict localhost, backend sebagai proxy | User, 11 Nov |
| Lokasi: buang IP, tanya sekali "mau nyari kerja di daerah mana", simpan lokal | User, 11 Nov |
| CV tidak auto-hapus; bisa dihapus/dibiarkan; reuse untuk apply | User, 11 Nov |
| Privasi patuh GDPR; consent checkbox; Privacy Policy + ToS | User, 11 Nov |
| Deploy VPS (sudah dites, jalan); domain ada; Cloudflare nanti | User, 11 Nov |
| Monetisasi di course/pembelajaran | User, 11 Nov |
| Mobile sudah ada di Stellar — renovasi saja | User, 11 Nov |
| CV rusak: pesan tegas, perbaiki dan scan ulang | User, 11 Nov |
| Testing manual full flag; tanpa Gemini di CI/CD; round-robin free model 9Router | User, 11 Nov |
| Ranking v1 dimatangkan; v2 tetap di plan (unused code atau desain — tanya backdev) | User, 11 Nov |
| Metrik = gap terbesar; .md terpisah untuk team meet | User, 11 Nov |
| Reviewer PRD: user + 1 orang lagi | User, 11 Nov |
| backdev 1 orang, frontdev 1 orang; user bisa bantu keduanya | User, 11 Nov |
| Nama tim admin123 memang itu namanya; nama produk JosJob | Abstrak final + user, 10–11 Nov |

## 5. Sumber yang dipakai

- Repo `ZygmaCore/job-seeker-ai`: `README.md`, `docs/ringkasan-project-untuk-abstrak.md`,
  `docs/01–10`, `docs/api/*`, `docs/specs/*`, `docs/enhancement/*`,
  `docs/plans/*`, `CLAUDE.md`, `AGENTS.md`, `mix.exs`, `pubspec.yaml`.
- Abstrak final JosJob (PDF) — otoritatif bila ada konflik.
- Handbook STACK 2026 (PDF) — timeline, aturan originality, kriteria
  penilaian, format submission.
- Plan awal tim (`plan__sebelum_penambahan_stelar.md`, 73 baris, excerpt —
  Minggu 1–2 tidak ada di file) dan PRD awal
  (`PRD_awal__sebelum_penambahan_stellar.md`, 55 baris, excerpt bagian
  akhir saja) — keduanya **sebelum** penambahan Stellar.
- Rincian tugas Notion user (screenshot, 11 Nov 2026).

## 6. Yang sengaja TIDAK ada di PRD ini

- Code (tidak ada code yang ditulis untuk PRD ini).
- Target metrik (belum disepakati — lihat `METRICS.md`).
- Pemetaan nama anggota ke peran frontdev/backdev (belum diputuskan —
  lihat `DECISIONS.md` O14).
- Isi hukum final Privacy Policy/ToS (butuh tinjauan tim).
- Keputusan birokrasi/stakeholder mapping dan dependensi Notion yang
  user minta di-skip (gap no. 7 dan no. 9 dari gap analysis 11 Nov).
