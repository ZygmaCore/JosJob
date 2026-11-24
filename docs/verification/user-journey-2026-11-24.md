# Audit dan perbaikan alur pengguna — 24 November 2026

Acuan: `PRD/PRD.md`, keputusan D18/D19/D22/D23, source/test pada working tree
berbasis `fa8be2cfafa2a37eeeff05bd34dda199dc4c282b`. Snapshot Graphify lama
tidak digunakan sebagai bukti implementasi.

## Temuan yang diperbaiki

| Bagian alur | Masalah | Perilaku setelah perbaikan |
| --- | --- | --- |
| Registrasi/login | Input berlabel visual tetapi nama aksesibilitas mengikuti placeholder; klaim quiz/sertifikasi mendahului implementasi | Label terhubung ke input; informasi fitur mengikuti produk saat ini; pustaka Google khusus browser dipisahkan agar tes registrasi dapat berjalan |
| Unggah CV | Compose tidak menjalankan layanan ekstraksi; backend mengarah ke localhost container sendiri | Layanan PDF dengan qpdf/pdftotext tersedia lewat Docker DNS, token bersama, dan healthcheck |
| Tinjau CV | Skill ekstraksi tidak dapat dikoreksi; proses hilang dari UI setelah berpindah halaman | Editor skill sebelum menerima hasil; ID ekstraksi disimpan per akun/perangkat dan polling dapat dilanjutkan |
| CV → Apply | Fakta hasil analisis dan profil yang dikirim ke employer berbeda | Fakta yang ditinjau disimpan bersama analisis; editor profil, ranking dan saran kelas memakai skill yang sama |
| Pencarian | Lokasi hilang ketika kembali membuka lowongan | Preferensi lokasi disimpan per akun/perangkat tanpa menahan pemuatan awal lowongan |
| Apply → Learn → Apply | Profil panjang menutupi form; draf rentan hilang; jalan kembali kurang jelas | Ringkasan profil dapat diperluas; Edit CV dari Apply; draf per akun/lowongan; dua saran awal dengan Show all; Back to application |
| Belajar | My Courses tidak membuka kelas/materi; URL materi berbayar bocor sebelum enrollment | Kartu membuka detail; materi tersedia untuk enrollment/instruktur/pengelola yang berhak; status materi kosong dijelaskan |
| Keluar kelas | Pembatalan enrollment terlalu mudah | Konfirmasi sebelum meninggalkan kelas dengan informasi refund yang sesuai |
| Setelah Apply | Mengulang Apply menghasilkan jalan buntu duplicate | Detail lowongan membuka lamaran sendiri; konflik submit mengarahkan ke lamaran yang sudah ada; status menampilkan langkah berikutnya |

Migrasi `20261124111816_add_reviewed_candidate_cv_facts.exs` mengadopsi analisis
terbaru milik kandidat ke profil, mempertahankan headline/summary/PDF yang
dipilih. Lamaran lama tetap memakai snapshot saat dikirim; perubahan CV berikutnya
tidak mengubahnya. `cv_facts` dan identitas pemilik tidak dapat dipalsukan melalui
PATCH profil.

## Validasi

- `mix precommit`: 420 tes dan 2 doctest, tanpa kegagalan, di Linux Docker.
- Seluruh tes Flutter: 130 lulus (termasuk satu tes registrasi lokal yang sudah
  ada); setelah perubahan aksesibilitas terakhir, registrasi dan responsive Apply
  diuji ulang: 2 lulus.
- Analisis Flutter untuk area yang berubah: tanpa issue. Analisis seluruh proyek
  masih melaporkan 10 warning lama pada komponen landing yang tidak digunakan.
- Build rilis backend dan Flutter web berhasil; image lokal diperbarui dan
  migrasi dijalankan melalui entrypoint backend.
- 10 tes HTTP rekomendasi terhadap Docker lulus, termasuk enam akun demo,
  isolasi CV, kelas nyata sementara, dan larangan saran untuk lowongan tidak aktif.
- 2 skenario browser Chrome lulus (desktop 1440×1000 dan mobile 390×844):
  guest → login kembali ke Apply → unggah PDF asli → koreksi hasil → enrollment
  kelas → buka materi PDF → kembali ke draf → reload → edit skill → submit →
  employer mengubah status via API → kandidat melihat Reviewing → mengirim chat
  → membuka kembali lamaran → My Courses membuka materi → konfirmasi keluar
  kelas dibatalkan. Skenario kedua memvalidasi registrasi baru, identitas wajib,
  melewati onboarding opsional, dan akses lowongan. Tidak ada browser page error.
  Screenshot delapan tahap tersedia lokal di `e2e/test-results/candidate-journey/`.
- Regresi browser login dari Apply setelah reload halaman login: 1 lulus.
  Total validasi live: 3 skenario browser dan 10 tes HTTP.

Tes browser lokal tambahan ada di `e2e/tests/candidate-journey.spec.ts`, dengan
fixture eksplisit `e2e/fixtures/candidate_journey.exs`. Fixture menggunakan
organisasi/akun/lowongan/kelas bertanda synthetic dan dibersihkan lewat cabang
cleanup yang memeriksa penanda. File PDF yang dipakai adalah demo publik
`apps/josjob_web/priv/static/assets/demo-cvs/backend.pdf`. Provider pengujian
diatur ke `keyword`; pengujian ini tidak mengirim CV ke API AI berbayar.

Setelah validasi, seluruh akun/organisasi/lowongan/kelas/enrollment/analisis
fixture dibersihkan dan keberadaannya dicek kembali di database. Enam akun demo
CV dan 20 lowongan demo aktif tetap tersedia. Provider ekstraksi dikembalikan ke
`gemini,nine_router,keyword`; container PDF direkreasi sehingga antrean sementara
uji tidak tertinggal. Frontend dan health PDF merespons HTTP 200; API lowongan
merespons normal. Container kompilasi/pengujian dihentikan; database, backend,
frontend dan PDF service tetap berjalan.

## Batas dan pekerjaan PRD berikutnya

- Curriculum terstruktur, progress pembelajaran, quiz dan penerbitan sertifikat
  otomatis masih pekerjaan lanjutan D18. Enrollment saja tidak menambahkan skill
  atau mengklaim kelulusan; kandidat dapat memperbarui skill dan melakukan rematch.
- Terms/Privacy masih secara eksplisit berstatus preview; dokumen legal final
  dan kontrol penghapusan seluruh data CV belum disediakan oleh perubahan ini.
- PDF mentah untuk ekstraksi bersifat sementara. Melampirkan PDF ke lamaran
  tetap pilihan terpisah dari library dokumen milik kandidat.
- Pembayaran Stripe nyata, Google OAuth nyata, kualitas Gemini/9Router dan sesi
  coaching/video eksternal tidak divalidasi dengan transaksi atau panggilan live.
