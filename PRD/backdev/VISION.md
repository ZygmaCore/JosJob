# VISION Backend — JosJob (rencana ke depan)

> Dokumen ini berisi rencana **setelah** hackathon / di luar scope MVP.
> Bukan untuk dikerjakan sekarang, kecuali tim memutuskan sebaliknya.
> Setiap item di sini harus dibaca sebagai "desain/ide", bukan fitur jadi.

## 1. Ranking v2 (desain, bukan code — kecuali tim memutuskan lain)

V2 menambah sinyal di atas v1 (match + recency):

- **Popularitas:** views/saves/applies/CTR per user unik, dengan time decay.
- **Affinity:** kategori/industri/lokasi yang pernah diklik/disave user.
- **Kualitas listing:** lowongan lengkap + employer terverifikasi naik.
- **Eksplorasi:** 10–20% slot untuk lowongan baru/kurang terekspos
  (anti rich-get-richer), plus campuran di luar preferensi (anti filter
  bubble).
- **Anti-gaming:** hitung user unik, bukan hit mentah; rate limit view.

**Keputusan yang masih terbuka (penting):** apakah v2 ditulis sebagai
*unused code for future use* atau hanya sebagai desain di dokumen?
Rekomendasi PRD: **desain saja, jangan tulis dead code.** Alasannya: code
yang tidak dipakai membusuk, membingungkan reviewer repo (termasuk juri yang
membaca repo), dan dapat menggagalkan CI. V2 diaktifkan hanya bila ada
keputusan tim + token/waktu. Bila tim tetap ingin code-nya ditulis duluan,
syaratnya: berada di balik feature flag yang jelas, ter-cover test, dan
tercatat di dokumen ini sebagai "nonaktif".

Bobot v2 belum diputuskan. Bobot harus tunable (konstanta bernama +
terdokumentasi), bukan magic number di tengah fungsi.

## 2. Lokasi yang lebih pintar (setelah v1)

- Saat ini: lokasi dari jawaban user sekali ("mau nyari kerja di daerah
  mana"), disimpan lokal di browser, bobotnya hanya sinyal awal dan
  terdegradasi oleh perilaku user.
- Ke depan (perlu dikaji): apakah bobot lokasi boleh naik lagi bila user
  secara konsisten mencari di satu daerah? Apakah lokasi boleh disimpan di
  profil (server) bila user meminta secara eksplisit? Keduanya butuh
  keputusan privasi baru — jangan implementasikan diam-diam.

## 3. Quiz bergating + sertifikat (desain di docs/07–08)

- Placement quiz, lecture/section quiz, live quiz & poll, gamifikasi
  leaderboard, progress heartbeat, gating (90%/70%/75%), sertifikat PDF
  bertanda SHA256 + verifikasi QR.
- Status saat ini: desain + UI Flutter sample saja; `stellar_quiz` masih
  stub. Bila dikerjakan nanti, resource `Quiz/Question/Submission/
  EnrollmentProgress/Certificate` harus dibuat dari nol, dan gating harus
  divalidasi server-side (bukan hanya di UI).

## 4. RAG Q&A streaming (desain di docs/09)

- Ingestion ke Atomic Server sudah ada (`stellar_rag`). Yang belum ada:
  retrieval visibility-aware + streaming jawaban via channel
  `user:ai_assistant:*` (channel itu tidak terpasang di `UserSocket`).
- Bila dikerjakan nanti: retrieval harus menghormati visibility per-course
  per-org yang sama dengan ingestion; jangan bocorkan atom antar organisasi.

## 5. Notifikasi push (desain di docs/06)

- FCM tidak ada di dependensi saat ini. Bila dibutuhkan nanti, tambahkan
  `firebase_messaging` di Flutter + pengiriman background via Oban, dan
  perbarui Privacy Policy (token push adalah data pribadi).

## 6. Live chat / kolaborasi (desain di docs/05)

- Chat per-room sebagai GenServer + DynamicSupervisor + write-back buffer.
  Saat ini hanya channel `live_room:*` dan `user:notifications:*` yang
  terpasang. Chat/quiz/ai_assistant channel masih "menyusul" menurut komentar
  code — jangan diklaim sudah ada.

## 7. Deployment go-public (bila menang)

- Arsitektur deployment dimatangkan lagi: pemisahan secret, backup database,
  monitoring/observability (log, metrik, alert), rate limit di edge
  (Cloudflare), dan rencana kalau VPS down saat demo/penjurian.
- Cloudflare: DNS + TLS + CDN di depan VPS, bareng streaming yang sudah ada
  di Stellar.
- Pertimbangkan: apakah 9Router tetap di VPS yang sama atau dipisah?
  Bila dipisah, akses localhost-only tidak lagi berlaku dan butuh desain
  jaringan + autentikasi antar service yang baru.

## 8. Hal yang sengaja TIDAK ada di vision ini

- Scraping lowongan (batal, permanen).
- Menjual data CV/pengguna.
- Screening otomatis lamaran untuk recruiter tanpa keputusan tim + tanpa
  pemberitahuan ke kandidat (risiko bias dan masalah privasi).
