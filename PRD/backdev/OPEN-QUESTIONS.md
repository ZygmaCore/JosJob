# OPEN QUESTIONS — Backend (untuk AI-nya backdev)

> **Cara pakai dokumen ini:** AI yang membantu backdev **wajib menanyakan**
> pertanyaan di bawah ini ke backdev sebelum mengimplementasikan bagian yang
> terkait. Jangan memilih sendiri secara diam-diam. Tulis jawaban + tanggal
> keputusan di kolom "Keputusan" begitu diputuskan.

## Q1. Bobot ranking v1

**Pertanyaan:** Berapa bobot match vs recency di ranking v1?

- Opsi A: match 70% + recency 30%.
- Opsi B: match 80% + recency 20%.
- Opsi C: match 100% dulu (recency hanya tie-breaker), recency baru
  ditambahkan setelah diuji.
- Opsi D: bobot lain (tulis angkanya).

**Rekomendasi dokumen ini:** C untuk demo (paling bisa dijelaskan), lalu A.
**Keputusan:** _(belum diputuskan)_

## Q2. Model yang di-pin untuk demo

**Pertanyaan:** Model apa yang dipakai sebagai primary saat demo?

- Opsi A: satu model Gemini (extraction + embedding).
- Opsi B: satu model 9Router tertentu (tulis nama modelnya).
- Opsi C: tidak di-pin — round-robin penuh sejak awal.

**Rekomendasi dokumen ini:** A, dengan round-robin hanya sebagai fallback.
**Keputusan:** _(belum diputuskan)_

## Q3. Ranking v2: desain atau unused code?

**Pertanyaan:** Apakah v2 ditulis sebagai code yang tidak dipakai, atau hanya
sebagai desain?

- Opsi A: hanya desain di dokumen (rekomendasi PRD).
- Opsi B: code di balik feature flag yang jelas + test.
- Opsi C: code ditulis penuh tapi tidak dipanggil (dead code).

**Rekomendasi dokumen ini:** A. Opsi C tidak direkomendasikan.
**Keputusan:** _(belum diputuskan)_

## Q4. Set status lamaran

**Pertanyaan:** Status lamaran apa saja yang didukung?

- Opsi A: Pending / Reviewed / Accepted / Rejected.
- Opsi B: A + Interview + Offer.

**Rekomendasi dokumen ini:** B bila mudah; A cukup untuk demo.
**Keputusan:** _(belum diputuskan)_

## Q5. Lowongan langsung aktif atau butuh approval?

**Pertanyaan:** Employer membuat lowongan — langsung aktif atau butuh
approval admin/superuser dulu?

- Opsi A: langsung aktif.
- Opsi B: butuh approval.

**Rekomendasi dokumen ini:** A untuk demo.
**Keputusan:** _(belum diputuskan)_

## Q6. Ambang "partial" vs "unreadable"

**Pertanyaan:** Kapan hasil ekstraksi disebut `partial` dan kapan
`unreadable`?

- Opsi A: panjang teks terekstrak minimum.
- Opsi B: jumlah field terisi minimum.
- Opsi C: kombinasi keduanya.

**Rekomendasi dokumen ini:** C.
**Keputusan:** _(belum diputuskan)_

## Q7. Retensi log dan analisis lama

**Pertanyaan:** Berapa lama log aplikasi dan hasil analisis lama disimpan?

- Opsi A: 30 hari, lalu dihapus otomatis.
- Opsi B: 90 hari.
- Opsi C: disimpan selama akun ada, dihapus bersama akun.

**Catatan:** CV sendiri tidak dihapus otomatis (keputusan tim) — pertanyaan
ini hanya soal log + hasil analisis lama.
**Keputusan:** _(belum diputuskan)_

## Q8. Decay bobot lokasi

**Pertanyaan:** Bagaimana tepatnya bobot lokasi terdegradasi oleh perilaku
user?

- Opsi A: decay waktu (misal bobot berkurang tiap minggu tanpa sinyal baru).
- Opsi B: decay oleh perilaku (tiap pencarian di luar lokasi awal
  mengurangi bobot).
- Opsi C: kombinasi A + B.

**Keputusan:** _(belum diputuskan — masih perlu dikaji)_

## Q9. Penyimpanan embedding

**Pertanyaan:** Embedding CV/lowongan disimpan di mana?

- Opsi A: ParadeDB + pgvector (image ParadeDB sudah pgvector-capable).
- Opsi B: Atomic Server (sudah dipakai `stellar_rag` untuk ingestion).
- Opsi C: kolom di Postgres biasa (vector sebagai array) untuk v1, pindah
  nanti bila perlu.

**Rekomendasi dokumen ini:** tanyakan ke backdev; C paling sederhana untuk
demo, A paling benar untuk jangka panjang.
**Keputusan:** _(belum diputuskan)_
