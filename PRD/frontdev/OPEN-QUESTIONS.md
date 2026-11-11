# OPEN QUESTIONS — Frontend (untuk AI-nya frontdev)

> **Cara pakai dokumen ini:** AI yang membantu frontdev **wajib menanyakan**
> pertanyaan di bawah ini ke frontdev sebelum mengimplementasikannya.
> Jangan memilih sendiri secara diam-diam. Tulis jawaban + tanggal keputusan
> di kolom "Keputusan" begitu diputuskan.

## Q1. Struktur hero landing page

**Pertanyaan:** Elemen utama hero apa?

- Opsi A: search bar besar sebagai elemen utama.
- Opsi B: CTA "Upload CV" sebagai elemen utama, search di bawah.
- Opsi C: gabungan (search + upload CV berdampingan).
- Opsi D: struktur lain (tulis sketsanya).

**Rekomendasi dokumen ini:** C.
**Keputusan:** _(belum diputuskan)_

## Q2. Kapan pertanyaan lokasi diajukan?

**Pertanyaan:** Kapan user ditanya "mau nyari kerja di daerah mana"?

- Opsi A: saat onboarding.
- Opsi B: saat pertama kali membuka ranking.
- Opsi C: keduanya (onboarding + bisa diubah di pengaturan).

**Rekomendasi dokumen ini:** C.
**Keputusan:** _(belum diputuskan)_

## Q3. IndexedDB mentah di v1 atau Drift saja?

**Pertanyaan:** Apakah v1 tetap dengan Drift yang sudah ada, atau ada
kebutuhan spesifik yang memaksa IndexedDB mentah di v1?

- Opsi A: Drift saja di v1; IndexedDB hanya desain v2.
- Opsi B: IndexedDB mentah sudah di v1 (tulis alasannya).

**Rekomendasi dokumen ini:** A.
**Keputusan:** _(belum diputuskan)_

## Q4. Tampilan skor fallback

**Pertanyaan:** Bagaimana label skor yang berasal dari fallback keyword
ditampilkan?

- Opsi A: badge kecil "skor sementara (keyword)" di kartu.
- Opsi B: banner di atas daftar ranking.
- Opsi C: keduanya.

**Rekomendasi dokumen ini:** A.
**Keputusan:** _(belum diputuskan)_

## Q5. Data sample jobs_data.dart

**Pertanyaan:** Apa yang terjadi dengan `jobs_data.dart` (6 lowongan
hard-coded) setelah backend jobs jadi?

- Opsi A: dihapus sepenuhnya.
- Opsi B: dipertahankan sebagai seed/fallback dengan label jelas
  "data contoh".

**Rekomendasi dokumen ini:** A (hapus) — data contoh yang tersisa adalah
sumber kebingungan saat demo.
**Keputusan:** _(belum diputuskan)_

## Q6. Wording consent checkbox

**Pertanyaan:** Teks consent sebelum CV diproses berbunyi bagaimana?

- Opsi A: singkat (1 kalimat + tautan Privacy Policy).
- Opsi B: lebih rinci (menyebut Gemini / provider 9Router secara eksplisit
  di teks checkbox).
- Opsi C: teks lain (tulis drafnya).

**Rekomendasi dokumen ini:** B — karena CV dikirim ke pihak ketiga, user
harus tahu ke mana datanya pergi sebelum mencentang.
**Keputusan:** _(belum diputuskan)_
