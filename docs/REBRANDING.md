# Transisi identitas aplikasi ke JosJob

Branch `refactor/stellar-to-josjob` menyeragamkan identitas seluruh source.
Merek yang ditampilkan kepada pengguna adalah **JosJob**, namespace Elixir
adalah `Josjob*`, dan nama teknis app/package/release memakai `josjob*`.

| Sebelum | Sesudah |
| --- | --- |
| `Stellar`, `StellarWeb`, `StellarLrn`, dan namespace lain | `Josjob`, `JosjobWeb`, `JosjobLrn`, dan namespace sesuai app |
| `apps/stellar*` | `apps/josjob*` |
| Release `stellar` | Release `josjob` |
| Package Flutter `stellar_fe` | `josjob_fe` |
| Service Compose `stellar_be`, `stellar_fe` | `josjob_be`, `josjob_fe` |
| Database default `stellar_dev`, `stellar_test` | `josjob_dev`, `josjob_test` |
| Android `com.atveti.stellar_fe` | `com.atveti.josjob_fe` |
| iOS `com.atveti.stellarFe` | `com.atveti.josjobFe` |

## Instalasi baru

Ikuti [README](../README.md) dengan path baru. Mulai frontend dari
`apps/josjob_fe`; build release memakai `MIX_ENV=prod mix release josjob`.
Dockerfile dan semua Compose file memakai nama app/service/image baru.

## Instalasi yang sudah berjalan

Penggantian source tidak menjalankan operasi database, menghapus volume,
mengganti kredensial, atau mengubah file `envs/.env` lokal.

1. Selesaikan sinkronisasi onboarding pada aplikasi lama sebelum beralih.
   Browser memakai namespace penyimpanan baru untuk token (`josjob.*`), draft
   onboarding (`josjob.onboarding_draft.*`) dan outbox (`josjob_outbox`).
   Data lokal lama tidak disalin otomatis. Jangan menghapus data browser jika
   masih ada perubahan offline yang belum terkirim; sinkronkan dengan versi
   lama dahulu. Pengguna perlu login ulang, termasuk sesi browser Phoenix
   yang kini memakai cookie `_josjob_web_key`.
2. Untuk tetap menggunakan database yang sudah ada, pertahankan nilai
   `POSTGRES_DB` atau `DATABASE_URL` yang menunjuk ke database tersebut.
   Default baru hanya berlaku jika tidak ada override. Tabel, kolom, dan nomor
   versi migrasi tetap sama; migrasi lama tidak perlu dijalankan ulang paksa.
3. Gunakan volume Compose yang sama. Nama volume `paradedb_data` tetap sama;
   nama project Compose dan override deployment juga harus tetap konsisten.
   Hentikan container backend/frontend versi lama sebelum menjalankan service
   baru untuk menghindari konflik port. Jangan gunakan `down -v` untuk transisi.
4. Jalankan `mix deps.get` dan `flutter pub get` dari path baru. Rebuild backend,
   asset Phoenix dan bundle Flutter, lalu gunakan script `rel/overlays/bin`
   yang sekarang memanggil `Josjob.Release` dan executable `josjob`.
5. Perbarui referensi service/image/release dalam konfigurasi deployment di
   luar repo. Android/iOS memiliki application/bundle ID baru dan dianggap
   sebagai identitas aplikasi berbeda. Sesuaikan signing, OAuth client native,
   dan registrasi platform sebelum distribusi; data instalasi lama tidak
   otomatis berpindah ke ID baru. URL API dan route HTTP tidak berubah.

## Layanan eksternal dan index kode

Default hostname Atomic Server yang sudah digunakan tetap
`https://stellar-rag.onprem.vip`. Itu adalah alamat infrastruktur eksternal,
bukan nama package atau merek UI. Mengganti source tidak membuat record DNS
baru. Gunakan environment build `ATOMIC_BASE_URL` untuk memilih alamat lain;
`ATOMIC_API_TOKEN` tetap menjadi konfigurasi token yang ada.

Graphify masih dapat menampilkan namespace dan path dari snapshot sebelum
rename. Gunakan source lokal sampai index repository diperbarui. Dokumen
historis telah menyesuaikan path/nama untuk navigasi; timestamp, commit, dan
hasil verifikasi lama bukan bukti bahwa branch refactor telah lulus runtime.

## Verifikasi branch rename

Pada 2026-11-12, `flutter analyze` dan `flutter build web` berhasil dari
`apps/josjob_fe`. Sebanyak 53 test Flutter yang kompatibel dengan VM lolos.
Test lama `_tmp_register_flow_test.dart` tetap tidak dapat dikompilasi pada
VM karena import Google sign-in khusus browser; file itu tidak diperbaiki
dalam refactor nama ini.

Pemeriksaan sintaks terhadap 273 file Elixir/config/test berhasil. Seluruh
846 file yang dilacak sebelum refactor tersedia di path hasil rename;
sepuluh app umbrella dan dependency lokalnya memiliki nama/folder yang cocok.
Validasi lanjutan pada hari yang sama berhasil menjalankan `mix precommit`
di Debian WSL: 234 test dan 7 doctest lolos setelah dependency native tersedia
dan bootstrap database test diperbaiki. Startup HTTP juga diverifikasi;
lihat [testing backend](BACKEND_TESTING.md). Android/iOS build dan transisi
data instalasi lama belum diuji.
