# PRD Frontend — JosJob (frontdev)

> **Scope dokumen ini:** frontend saja (Flutter, `apps/josjob_fe` — satu
> aplikasi unified untuk web; mobile = codebase Flutter yang sama,
> direnovasi). Backend ada di `../backdev/PRD.md`. Keputusan level tim ada
> di `../PRD.md`. Dokumen ini ditulis dalam Bahasa Indonesia dengan istilah
> teknis Inggris.
>
> **Untuk AI-nya frontdev:** dokumen ini memberi konteks yang kaya + pilihan
> di setiap keputusan yang belum final. Kalau ada pilihan, **tanyakan ke
> frontdev** sebelum mengimplementasikannya — jangan memilih sendiri secara
> diam-diam. Pilihan yang belum diputuskan dikumpulkan di
> `OPEN-QUESTIONS.md`.
>
> **House rules repo (wajib):** `CLAUDE.md` di root repo untuk struktur
> frontend. Yang paling relevan: satu modul = satu library Dart
> (`part`/`part of`); komponen private (`_Foo`), hanya entry widget modul
> yang public; design token selalu `AppColors` + `Bp` dari
> `theme/app_theme.dart`; font Poppins via `google_fonts`. Setelah mengubah
> UI, `flutter analyze` harus **No issues found** dan `dart format lib`
> harus bersih. Untuk perubahan visual, verifikasi dengan headless golden
> screenshot, bukan dengan menebak.

## 1. Tujuan scope frontend

Merenovasi Flutter Web JosJob yang sudah ada menjadi JosJob, sehingga
graduate dapat: melihat lowongan, mengupload CV, melihat ranking +
penjelasan, mengambil kursus untuk skill yang hilang, dan melamar — semuanya
dalam satu pengalaman (landing → auth → onboarding → dashboard Learn | Jobs).

**Non-goals scope ini:** logika ranking/matching (backend), pembuatan model
AI, dan perubahan API (itu backdev — tapi kontrak API disepakati bersama,
lihat `../backdev/PRD.md` §2.3).

## 2. Struktur yang sudah ada (renovasi, bukan bangun ulang)

Aplikasi Flutter sudah unified: `landing/` (hero, program, steps/milestone,
stats, testimonials, FAQ), `auth/`, `onboarding/`, `dashboard/` (switcher
Learn | Jobs, role-adaptive), `explore/` (katalog course), `quiz/` (UI-only),
`jobs/` (board lowongan — **saat ini UI-only, 6 lowongan hard-coded**),
`vod/`, `live/`, `teacher/`, `admin/`, `invite/`, `documents/`, `services/`
(`auth_api.dart`, `courses_api.dart`, `documents_api.dart`, `vod_api.dart`,
`sync/` offline-first via Drift).

**Yang berubah di hackathon (prioritas):**

| Modul | Perubahan |
| --- | --- |
| `landing/` | Renovasi total — fusi Upwork (atas) + Glints (bawah), lihat §3. |
| `jobs/` | Dari UI-only hard-coded menjadi terhubung backend: daftar, detail, ranking + penjelasan, apply. Hapus `jobs_data.dart` sebagai sumber data (boleh dipertahankan sebagai seed/fallback yang diberi label jelas, tapi bukan sumber utama). |
| `auth/` + `onboarding/` | Renovasi ringan: tambah consent checkbox (lihat §7), tambah pertanyaan lokasi sekali (lihat §6). |
| `dashboard/` | Tambah kartu/section ranking + skill gap + hook kursus. |
| Baru: CV upload | Alur upload + status analisis + hasil ekstraksi yang bisa dikoreksi. |
| Baru: Privacy Policy + ToS | Halaman statis + tautan dari footer dan dari consent checkbox. |
| `quiz/` | Jangan disentuh (di luar scope). |

## 3. Landing page — fusi Upwork (atas) + Glints (bawah)

Renovasi ini milik frontdev dan akan dikomunikasikan dengan tim. PRD ini
memberi struktur + pilihan, bukan keputusan sepihak.

### 3.1 Struktur yang disarankan

1. **Hero (atas, ala Upwork):** satu janji yang jelas + search bar yang
   menonjol + cara kerja 3 langkah ("Upload CV → Lihat ranking → Belajar
   dan lamar"). Catatan: Upwork adalah marketplace dua sisi (cari freelancer
   / cari klien) — JosJob targetnya fresh graduate cari kerja, jadi sisi
   atasnya harus "upload CV, dapat ranking yang cocok", bukan "hire talent".
2. **Preview lowongan ter-ranked (bawah, ala Glints):** kartu lowongan
   (logo, judul, perusahaan, lokasi, rentang gaji, match %, tag skill,
   save/apply) + filter + sort.
3. **Skill gap → kursus:** section yang menunjukkan contoh "skill hilang →
   kursus" sebagai teaser learning path.
4. **Kategori:** berdasarkan jenis pekerjaan/industri.
5. **CTA employer + FAQ + footer** (footer memuat tautan Privacy Policy
   dan ToS).

### 3.2 Yang harus dihindari

- Jangan copy copywriting/branding Upwork atau Glints — inspirasi visual
  dan struktur saja.
- Jangan isi angka trust/statistik karangan (stats di landing JosJob saat
  ini dapat memuat angka marketing — jangan dipakai sebagai klaim faktual
  sebelum diverifikasi tim).
- Landing harus responsif (web dulu; mobile = codebase yang sama).

### 3.3 Pilihan untuk frontdev (tanyakan)

- Opsi A: hero dengan search bar besar sebagai elemen utama.
- Opsi B: hero dengan CTA "Upload CV" sebagai elemen utama, search di bawah.
- Opsi C: hero gabungan (search + upload CV berdampingan).
- Opsi D: struktur lain (tulis sketsanya).

Rekomendasi dokumen ini: C, karena dua jalan masuk utama graduate adalah
mencari dan mengupload CV. Lihat `OPEN-QUESTIONS.md` Q1.

## 4. Daftar pekerjaan, detail, dan apply

- **Daftar (`jobs/`):** kartu lowongan dari backend (bukan lagi hard-coded).
  Tiap kartu: judul, perusahaan, lokasi, jenis pekerjaan, work_mode,
  rentang gaji (bila ada), match % (bila CV sudah dianalisis), tag skill,
  save, apply. Filter: jenis, industri, lokasi, work_mode, gaji. Sort:
  ranking (default), terbaru, gaji.
- **Detail:** deskripsi lengkap, requirements (skill list), highlights,
  match % + penjelasan, skill yang hilang + hook kursus (lihat §5.3),
  tombol apply + save. Bila belum login: tombol apply mengarah ke
  login/register, dan setelah login kembali ke lowongan yang sama.
- **Apply:** memakai CV yang dipilih user (CV tersimpan dapat dipakai ulang
  tanpa upload ulang). Setelah apply: konfirmasi + status awal lamaran,
  dan lamaran muncul di riwayat (`/applications`).
- **Riwayat lamaran:** daftar + status tiap lamaran (status mengikuti
  keputusan backdev, lihat `../backdev/OPEN-QUESTIONS.md` Q4).
- **State kosong:** bila filter tidak menghasilkan apa-apa, beri pesan jujur
  + saran (longgarkan filter/lokasi), jangan tampilkan halaman kosong.

## 5. CV upload dan hasil analisis

### 5.1 Alur

Upload PDF → progress → status analisis (`queued → processing → done |
partial | unreadable | failed`) → hasil.

### 5.2 Status dan pesan (kontrak dengan backend)

| Status | Tampilan |
| --- | --- |
| `queued` / `processing` | Progress yang jelas (bukan spinner tanpa keterangan). User boleh meninggalkan halaman; hasil diberitahu via notifikasi. |
| `done` | Hasil ekstraksi + ranking (lihat §5.3). |
| `partial` | Hasil ditampilkan + peringatan "sebagian data tidak terbaca, periksa dan koreksi". |
| `unreadable` | Pesan tegas: CV tidak terbaca, tidak ada informasi berguna yang terekstrak. Jalan keluar: perbaiki CV dan scan ulang. **Jangan** menampilkan ranking dari ketiadaan data. |
| `failed` | Pesan error + tombol coba lagi. Jangan menampilkan skor palsu. |

### 5.3 Hasil ekstraksi + ranking + penjelasan

- Tampilkan hasil ekstraksi sebagai **"hasil AI, periksa dulu"** — bukan
  sebagai fakta terverifikasi. User dapat **mengoreksi skill** hasil
  ekstraksi (edit profile) sebelum ranking dipakai.
- Tiap item ranking menampilkan: match %, skill yang cocok, **skill yang
  hilang**, dan penjelasan singkat kenapa item ini di atas.
- **Hook ke kursus (selling point):** tiap skill yang hilang yang punya
  kursus di JosJob menampilkan tautan langsung ke course/class tersebut
  ("Pelajari SQL → Course X, Class Y"). Skill yang tidak punya kursus
  menampilkan "belum ada kursus untuk skill ini" — jangan mengarang kursus.
- Bila skor berasal dari fallback keyword (backend memberi tahu), tampilkan
  label jujur (misal "skor sementara (keyword)").

### 5.4 Penyimpanan CV

- CV yang sudah diupload dapat dilihat, dihapus, atau dipakai ulang untuk
  apply ke lowongan lain.
- Hapus CV = hapus file + hasil ekstraksi + embedding (backend), dan UI
  harus mengonfirmasi penghapusan dengan jelas.
- CV **tidak** dihapus otomatis (keputusan tim).

## 6. Lokasi — tanya sekali, bukan IP lookup

- **IP lookup: DIBUANG.** Tidak ada permintaan lokasi dari browser
  (geolocation API) dan tidak ada IP lookup.
- Saat yang tepat (misal onboarding atau pertama kali membuka ranking),
  tanyakan sekali dengan bahasa sederhana: **"Mau nyari kerja di daerah
  mana?"** — bukan "buka lokasi", melainkan pertanyaan teks/pilihan daerah.
- Jawaban disimpan di **local browser saja** (bukan di server), sesuai
  keputusan sebelumnya. Konsekuensinya: lokasi bisa berbeda antar device —
  itu dapat diterima dan harus dicatat.
- Bila user tidak menjawab: ranking tetap jalan tanpa sinyal lokasi.
- **Pilihan untuk frontdev** (tanyakan): kapan pertanyaan diajukan? Opsi:
  (a) saat onboarding, (b) saat pertama kali membuka ranking, (c) keduanya
  (onboarding + bisa diubah di pengaturan). Rekomendasi dokumen ini: (c).
  Lihat `OPEN-QUESTIONS.md` Q2.

## 7. Consent, Privacy Policy, dan ToS

- **Consent checkbox** wajib ada sebelum CV diproses: checkbox + teks
  singkat yang menjelaskan CV akan diproses oleh AI (Gemini / provider di
  9Router) dan disimpan selama user tidak menghapusnya. Tanpa centang,
  upload tidak dapat dilanjutkan.
- **Halaman Privacy Policy dan ToS** (baru, statis): menjelaskan data apa
  yang dikumpulkan, ke mana CV dikirim (pihak ketiga), berapa lama disimpan,
  hak hapus, dan kontak. Tautan dari footer dan dari teks consent.
- Isi hukum final bukan tanggung jawab dokumen ini — frontdev membuat
  halaman + struktur, tim meninjau isinya sebelum go public.

## 8. Nonfungsional (frontend)

- **Offline/cache:** JosJob FE sudah offline-first via Drift + SQLite
  outbox (`services/sync/`). Untuk ranking: server yang menghitung ranking;
  client hanya meng-cache hasilnya + mencatat interaksi lalu sync saat
  online. **IndexedDB mentah vs Drift** — keputusan v1/v2 ada di §9.
  Jangan membuat dua store yang isinya tumpang tindih tanpa alasan.
- **Keamanan:** tidak ada secret/API key di bundle Flutter. Token disimpan
  di `flutter_secure_storage` (sudah ada). Semua panggilan AI lewat backend.
- **Aksesibilitas:** semua state punya pesan yang jelas; kontras dan ukuran
  teks mengikuti design token; tombol punya label yang bermakna.
- **Performa:** daftar ranking memakai pagination; gambar/logo di-cache;
  jangan memuat seluruh korpus lowongan ke memori sekaligus.

## 9. IndexedDB vs Drift — v1/v2 (masih perlu dikaji)

- **v1 (MVP):** pakai Drift yang sudah ada untuk cache + outbox. IndexedDB
  mentah **tidak** dipakai di v1, kecuali frontdev menemukan kebutuhan
  yang tidak bisa dipenuhi Drift.
- **v2 (desain dulu):** bila dibutuhkan, IndexedDB dipakai untuk cache
  daftar ranking + TTL + interaksi, dengan aturan: isinya hanya ID lowongan
  + skor + timestamp (bukan objek lengkap), TTL misal 15 menit, invalidasi
  saat CV/profile berubah, dan jangan simpan embedding CV di IndexedDB.
- **Pilihan untuk frontdev** (tanyakan): apakah v1 tetap dengan Drift saja,
  atau ada kebutuhan spesifik yang memaksa IndexedDB mentah di v1? Tulis
  alasannya. Lihat `OPEN-QUESTIONS.md` Q3.

## 10. Kriteria penerimaan (frontend, dapat diuji)

- [ ] Landing menampilkan hero + search + preview ranking; tidak ada angka
      karangan.
- [ ] Daftar lowongan berasal dari backend (bukan hard-coded); filter dan
      sort bekerja.
- [ ] Upload PDF → status terlihat → hasil `done` menampilkan ranking +
      penjelasan + skill yang hilang.
- [ ] CV rusak → pesan tegas "tidak terbaca" + jalan keluar; tidak ada
      ranking yang ditampilkan.
- [ ] Hasil ekstraksi dapat dikoreksi sebelum dipakai untuk ranking.
- [ ] Skill yang hilang menampilkan hook kursus bila ada, dan "belum ada
      kursus" bila tidak ada (tidak mengarang).
- [ ] Tanpa centang consent, upload tidak dapat dilanjutkan.
- [ ] Pertanyaan lokasi diajukan sekali; jawaban tersimpan lokal; ranking
      tetap jalan bila tidak dijawab.
- [ ] CV tersimpan dapat dipakai ulang untuk apply dan dapat dihapus dengan
      konfirmasi yang jelas.
- [ ] `flutter analyze` bersih dan `dart format lib` bersih.
