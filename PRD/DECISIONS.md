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
| D2 | Project dibangun **ON TOP Stellar yang sudah ada** (renovasi), bukan bangun ulang. | 2026-11-10 | User |
| D3 | Stack microservices Go/TypeScript/Python dari PRD awal **gugur**. Stack yang dipakai: Elixir/Phoenix + Ash + Flutter (modular monolith). | 2026-11-10 | User + verifikasi repo |
| D4 | **Scraping batal.** Data lowongan: synthetic + employer-posted. | 2026-11-10 | User |
| D5 | Monetisasi di sisi **pembelajaran/course** (Stripe, sudah ada di Stellar). Sisi job gratis untuk graduate. | 2026-11-11 | User |
| D6 | AI: **Gemini API free tier** sebagai primary (embed + LLM), fallback **9Router** (self-hosted, localhost-only). | 2026-11-11 | User |
| D7 | 9Router **STRICT localhost**; backend sebagai proxy. Alur: frontend → backend → 9Router → backend → frontend. | 2026-11-11 | User |
| D8 | **IP lookup dibuang.** Lokasi ditanyakan sekali ("mau nyari kerja di daerah mana"), disimpan di local browser saja. | 2026-11-11 | User |
| D9 | Privasi: patuh **GDPR**. Consent checkbox sebelum CV diproses. CV **tidak** dihapus otomatis; user boleh hapus atau biarkan; CV tersimpan dapat dipakai ulang untuk apply. Privacy Policy + ToS dibuat. | 2026-11-11 | User |
| D10 | Deploy di **VPS** (sudah dites build + deploy Stellar, jalan). Domain sudah ada. Cloudflare dipakai nanti (bareng streaming Stellar). Go-public: arsitektur deployment dimatangkan lagi bila menang. | 2026-11-11 | User |
| D11 | CV rusak/tidak terbaca: pesan tegas, tidak ada info berguna terekstrak; user memperbaiki CV dan scan ulang. Tidak ada penilaian terhadap AI-nya (model Gemini / 9Router). | 2026-11-11 | User |
| D12 | Testing: manual untuk full flag; **tanpa Gemini di CI/CD** (hindari rate limit). 9Router: farming banyak free model, round-robin. | 2026-11-11 | User |
| D13 | Ranking v1 dimatangkan dulu (match + recency, deterministik). Ranking v2 tetap ada di plan sebagai desain; apakah ditulis sebagai unused code masih pertanyaan terbuka untuk backdev. | 2026-11-11 | User |
| D14 | Istilah: "backend"/"frontend" = **orangnya** (backdev 1 orang, frontdev 1 orang; user dapat intervensi/membantu). | 2026-11-11 | User |
| D15 | Reviewer PRD: user + 1 orang lagi. | 2026-11-11 | User |
| D16 | PRD oneshot ini (folder `PRD/`) menggantikan PRD arsitektur v1 (13 halaman, 10 Nov 2026) sebagai acuan utama. | 2026-11-11 | User (permintaan oneshot) |

## 2. Keputusan yang masih terbuka (level tim)

| # | Pertanyaan | Opsi | Rekomendasi dokumen | Pemilik |
| --- | --- | --- | --- | --- |
| O1 | Rumus/bobot match v1 | Lihat `backdev/OPEN-QUESTIONS.md` Q1 | Match 100% dulu (recency tie-breaker), lalu 70/30 | backdev |
| O2 | Model yang di-pin untuk demo | Lihat `backdev/OPEN-QUESTIONS.md` Q2 | Satu model Gemini; round-robin hanya fallback | backdev |
| O3 | v2 sebagai unused code atau desain? | Lihat `backdev/OPEN-QUESTIONS.md` Q3 | Desain saja, jangan dead code | backdev |
| O4 | Set status lamaran | Lihat `backdev/OPEN-QUESTIONS.md` Q4 | Pending/Reviewed/Accepted/Rejected + Interview + Offer | backdev |
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

## 3. Ketegangan yang diketahui (bukan keputusan — dicatat agar tidak lupa)

- **T1.** Abstrak menyebut "monorepo of independently deployable
  microservices", repo adalah modular monolith (satu rilis OTP). Abstrak
  berlaku untuk submission, code berlaku untuk build.
- **T2.** Abstrak masih memuat baris disclaimer bahwa nama/angka/data
  diciptakan untuk contoh gaya — bertentangan dengan status abstrak sebagai
  final. Lihat O12.
- **T3.** Aturan originality handbook vs reuse Stellar: pekerjaan baru selama
  lomba adalah `stellar_job` + `stellar_ai` + integrasi; Stellar harus
  diatribusi, bukan diklaim sebagai karya baru. Declaration of Originality
  wajib di semifinal.
- **T4.** Round-robin free model (9Router) membuat skor tidak deterministik
  — bertentangan dengan tujuan ranking yang "bisa dijelaskan". Mitigasi:
  provenance + pin model untuk demo (lihat O2).
- **T5.** Nama tim "admin123" sudah dikonfirmasi sebagai nama beneran.
