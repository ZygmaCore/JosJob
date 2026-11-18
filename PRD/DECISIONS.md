# DECISIONS — JosJob (log keputusan level tim)

> Log ini mencatat keputusan yang sudah final dan yang masih terbuka.
> Setiap keputusan baru ditambahkan di sini dengan tanggal. Bila sebuah
> keputusan berubah, jangan hapus baris lamanya — tambahkan baris baru
> dengan status "digantikan oleh …".
>
> Keputusan scoped (backend saja / frontend saja) ada di
> `backdev/OPEN-QUESTIONS.md` dan `frontdev/OPEN-QUESTIONS.md`.

## 1. Keputusan final

| # | Keputusan | Tanggal | Sumber |
| --- | --- | --- | --- |
| D1 | Produk: **JosJob**, tim: **admin123**, Case 1. Anggota: Fathan Akram (Leader), Alhikam Dirga, Dimas Sakti, Juang Zebua. | 2026-11-10 | Abstrak final (otoritatif bila ada info rancu) |
| D2 | Project dibangun **ON TOP platform pembelajaran yang sudah ada** (renovasi), bukan bangun ulang. Nama platform telah diseragamkan melalui D17. | 2026-11-10 | User |
| D3 | Stack microservices Go/TypeScript/Python dari PRD awal **gugur**. Stack yang dipakai: Elixir/Phoenix + Ash + Flutter (modular monolith). | 2026-11-10 | User + verifikasi repo |
| D4 | **Scraping batal.** Data lowongan: synthetic + employer-posted. | 2026-11-10 | User |
| D5 | Monetisasi di sisi **pembelajaran/course** (Stripe, sudah ada di JosJob). Sisi job gratis untuk graduate. | 2026-11-11 | User |
| D6 | AI: **Gemini API free tier** sebagai primary (embed + LLM), fallback **9Router** (self-hosted, localhost-only). | 2026-11-11 | User |
| D7 | 9Router **STRICT localhost**; backend sebagai proxy. Alur: frontend → backend → 9Router → backend → frontend. | 2026-11-11 | User |
| D8 | **IP lookup dibuang.** Lokasi ditanyakan sekali ("mau nyari kerja di daerah mana"), disimpan di local browser saja. | 2026-11-11 | User |
| D9 | Privasi: patuh **GDPR**. Consent checkbox sebelum CV diproses. CV **tidak** dihapus otomatis; user boleh hapus atau biarkan; CV tersimpan dapat dipakai ulang untuk apply. Privacy Policy + ToS dibuat. | 2026-11-11 | User |
| D10 | Deploy di **VPS** (sudah dites build + deploy JosJob, jalan). Domain sudah ada. Cloudflare dipakai nanti (bareng streaming JosJob). Go-public: arsitektur deployment dimatangkan lagi bila menang. | 2026-11-11 | User |
| D11 | CV rusak/tidak terbaca: pesan tegas, tidak ada info berguna terekstrak; user memperbaiki CV dan scan ulang. Tidak ada penilaian terhadap AI-nya (model Gemini / 9Router). | 2026-11-11 | User |
| D12 | Testing: manual untuk full flag; **tanpa Gemini di CI/CD** (hindari rate limit). 9Router: farming banyak free model, round-robin. | 2026-11-11 | User |
| D13 | Ranking v1 dimatangkan dulu (match + recency, deterministik). Ranking v2 tetap ada di plan sebagai desain; apakah ditulis sebagai unused code masih pertanyaan terbuka untuk backdev. | 2026-11-11 | User |
| D14 | Istilah: "backend"/"frontend" = **orangnya** (backdev 1 orang, frontdev 1 orang; user dapat intervensi/membantu). | 2026-11-11 | User |
| D15 | Reviewer PRD: user + 1 orang lagi. | 2026-11-11 | User |
| D16 | PRD oneshot ini (folder `PRD/`) menggantikan PRD arsitektur v1 (13 halaman, 10 Nov 2026) sebagai acuan utama. | 2026-11-11 | User (permintaan oneshot) |
| D17 | Seragamkan identitas produk menjadi **JosJob**, namespace Elixir menjadi `Josjob*`, dan nama app/package/release menjadi `josjob*` pada branch refactor terpisah. Lihat `docs/REBRANDING.md` untuk transisi instalasi yang sudah ada. | 2026-11-12 | User |
| D18 | Live Coaching adalah layanan coach yang independen dari course: profil, availability dan booking sendiri. Course diarahkan ke curriculum halaman baca, video dan quiz. Course curriculum masih direncanakan; MVP coaching independen mengikuti D19. Lihat [proposal pemisahan](LEARNING_AND_COACHING_REDESIGN.md). | 2026-11-17 | User |
| D19 | MVP coaching: appointment 1-on-1, gratis terlebih dahulu. Group session dan paid coaching berada di luar versi pertama. | 2026-11-17 | User |
| D20 | Hiring memakai urutan **Applied → Reviewing → Interview → Offer → Hired**. Menggantikan rekomendasi status pada O4/Q4. | 2026-11-17 | User |
| D21 | Tambahkan chat untuk proses lamaran dan coaching; semua chat memakai tema visual bersama. | 2026-11-17 | User |
| D22 | Lowongan aktif dapat dilihat publik tanpa login, membership organisasi, atau provisioning setelah registrasi. Login diperlukan untuk melamar; manajemen lowongan dan data hiring tetap memakai izin organisasi. | 2026-11-18 | User |

## 2. Keputusan yang masih terbuka (level tim)

Pembaruan 2026-11-17: D20 menetapkan urutan hiring **Applied → Reviewing →
Interview → Offer → Hired** (user). D21 menetapkan chat untuk lamaran dan coaching
dengan tema visual yang sama (user). Implementasi pertama mengikat chat ke lamaran
atau booking coaching; detail akses dan batas fitur ada di
[kontrak aplikasi dan chat](../docs/api/applications-and-chat.md). O4 dijawab oleh D20.

| # | Pertanyaan | Opsi | Rekomendasi dokumen | Pemilik |
| --- | --- | --- | --- | --- |
| O1 | Rumus/bobot match v1 | Lihat `backdev/OPEN-QUESTIONS.md` Q1 | Match 100% dulu (recency tie-breaker), lalu 70/30 | backdev |
| O2 | Model yang di-pin untuk demo | Lihat `backdev/OPEN-QUESTIONS.md` Q2 | Satu model Gemini; round-robin hanya fallback | backdev |
| O3 | v2 sebagai unused code atau desain? | Lihat `backdev/OPEN-QUESTIONS.md` Q3 | Desain saja, jangan dead code | backdev |
| O4 | Set status lamaran | Lihat `backdev/OPEN-QUESTIONS.md` Q4 | Diputuskan pada D20 | backdev |
| O5 | Lowongan langsung aktif atau approval? | Lihat `backdev/OPEN-QUESTIONS.md` Q5 | Langsung aktif (demo) | backdev |
| O6 | Ambang partial vs unreadable | Lihat `backdev/OPEN-QUESTIONS.md` Q6 | Kombinasi panjang teks + field terisi | backdev |
| O7 | Struktur hero landing page | Lihat `frontdev/OPEN-QUESTIONS.md` Q1 | Search + Upload CV berdampingan | frontdev |
| O8 | Kapan pertanyaan lokasi diajukan? | Lihat `frontdev/OPEN-QUESTIONS.md` Q2 | Onboarding + bisa diubah di pengaturan | frontdev |
| O9 | IndexedDB mentah di v1? | Lihat `frontdev/OPEN-QUESTIONS.md` Q3 | Drift saja di v1 | frontdev |
| O10 | Metrik + target | Lihat `METRICS.md` | Diputuskan di team meet — jangan dikarang | tim |
| O11 | Angka BPS di abstrak | Verifikasi ke rilis resmi BPS atau hapus | Verifikasi dulu | user (dokumen) |
| O12 | Baris disclaimer "invented" di abstrak | Hapus sebelum submission | Hapus | user (dokumen) |
| O13 | Status submission preliminary 10 Nov | Sudah submit atau belum? | Konfirmasi segera | user (dokumen) |
| O14 | Siapa frontdev / backdev (nama)? | — | Tulis namanya di sini begitu diputuskan | tim |
| O15 | Format coaching versi pertama | 1-on-1 dahulu / 1-on-1 dan group | Diputuskan: 1-on-1 dahulu (D19) | user |
| O16 | Coaching gratis atau berbayar | Gratis dahulu / paid melalui Stripe | Diputuskan: gratis dahulu (D19); paid coaching ditunda | user |

## 3. Ketegangan yang diketahui (bukan keputusan — dicatat agar tidak lupa)

- **T1.** Abstrak menyebut "monorepo of independently deployable
  microservices", repo adalah modular monolith (satu rilis OTP). Abstrak
  berlaku untuk submission, code berlaku untuk build.
- **T2.** Abstrak masih memuat baris disclaimer bahwa nama/angka/data
  diciptakan untuk contoh gaya — bertentangan dengan status abstrak sebagai
  final. Lihat O12.
- **T3.** Aturan originality handbook vs reuse JosJob: pekerjaan baru selama
  lomba adalah `josjob_job` + `josjob_ai` + integrasi; JosJob harus
  diatribusi, bukan diklaim sebagai karya baru. Declaration of Originality
  wajib di semifinal.
- **T4.** Round-robin free model (9Router) membuat skor tidak deterministik
  — bertentangan dengan tujuan ranking yang "bisa dijelaskan". Mitigasi:
  provenance + pin model untuk demo (lihat O2).
- **T5.** Nama tim "admin123" sudah dikonfirmasi sebagai nama beneran.
