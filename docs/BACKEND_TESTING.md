# Testing backend di Linux / WSL

Backend memakai dependency native C dan Rust/NIF. Jalankan pemeriksaan penuh
pada Linux dengan glibc; WSL adalah jalur yang telah diverifikasi untuk host
Windows. Instalasi Elixir Windows saja tidak menyediakan seluruh toolchain
dan target binary yang diperlukan dependency ini.

## Persiapan

Gunakan Elixir 1.19.5 / OTP 27. Versi tool proyek ada di
[`../.tool-versions`](../.tool-versions). Di Debian, dependency sistem untuk
jalur test yang telah digunakan dapat dipasang dengan:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  erlang-dev erlang-tools erlang-ssh erlang-xmerl \
  build-essential git curl ca-certificates unzip \
  postgresql postgresql-contrib libheif1 pkg-config
```

Pasang Elixir melalui version manager atau release resmi yang sesuai OTP.
Paket Erlang terpisah `erlang-xmerl` dibutuhkan saat Swoosh dikompilasi.
Dependency C seperti bcrypt dan picosat memerlukan compiler serta header
Erlang. Xberg dan LazyHTML pada Linux x86_64 mengambil NIF precompiled;
pastikan shared library yang dibutuhkan tersedia. Lingkungan verifikasi
memakai `libheif` 1.23.6.

Opsi `force_build` bukan opsi dependency Mix yang valid dan telah dihapus dari
deklarasi Xberg. Pengaturan global tidak lagi memaksa source build. Untuk
build native khusus, Xberg menyediakan `XBERG_BUILD=true`; jalur itu memerlukan
Rust dan dependency build tambahan. Versi Xberg yang terkunci juga memilih
source build pada environment `dev`; gunakan `MIX_ENV=test` saat pengujian.

## Database test dan pemeriksaan

Gunakan PostgreSQL 16+ yang dapat dijangkau, lalu set variabel environment
shell sebelum Mix dijalankan. Contoh untuk PostgreSQL di dalam WSL:

```bash
export MIX_ENV=test
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD='<password database test lokal>'
export HEX_CACERTS_PATH=/etc/ssl/certs/ca-certificates.crt

mix local.hex --force
mix local.rebar --force
mix deps.get
mix precommit
```

Konfigurasi test membaca `POSTGRES_*` dari environment proses, bukan dari
`envs/.env`. Jika memakai ParadeDB yang dipublikasikan Docker ke host,
gunakan port host tersebut, biasanya `5438`.

Alias `test` di root umbrella menjalankan `ecto.create --quiet` dan
`ecto.migrate --quiet` sebelum app pertama menjalankan test. Ini diperlukan
karena startup app lain dapat memulai Repo/Oban sebelum alias milik app inti
dijalankan. Database bernama `josjob_test` dengan suffix opsional
`MIX_TEST_PARTITION`. Akun database perlu izin membuat database test.

`mix precommit` menjalankan compile dengan warnings-as-errors, pemeriksaan
dependency yang tidak dipakai, formatter, dan seluruh suite. Untuk pemeriksaan
lanjutan terarah, gunakan `mix test <path_test.exs>`.

## Source Windows dan cache Linux

Simpan build/cache Linux terpisah dari build Windows. Pada mesin yang dipakai
untuk verifikasi, Debian WSL dan toolchain berikut sudah disiapkan:

- Elixir: `/opt/josjob-elixir-1.19.5/bin`
- Salinan source/cache test: `/root/josjob-backend-test`
- PostgreSQL: cluster `17/main`, port Linux `5432`

Cluster test baru ini memakai akun `postgres` dengan password lokal
`josjob-test-local`. Gunakan nilai tersebut untuk `POSTGRES_PASSWORD` saat
mengulang pemeriksaan pada lingkungan yang sudah disiapkan ini.

Salinan source Linux itu terpisah dari working tree Windows. Setelah source
Windows berubah, sinkronkan ulang source sebelum menguji. Contoh di WSL,
sesuaikan path repositori dengan checkout yang digunakan:

```bash
repo=/mnt/c/Users/LOQ/Documents/JosJob
test_dir=/root/josjob-backend-test
mkdir -p "$test_dir"
(cd "$repo"; git ls-files -z | tar --null -T - -cf -) | tar -xf - -C "$test_dir"
cd "$test_dir"
export PATH=/opt/josjob-elixir-1.19.5/bin:$PATH
# Set POSTGRES_* sesuai database lokal, lalu:
MIX_ENV=test mix precommit
```

Perintah sinkronisasi tersebut menyalin file yang dilacak Git, termasuk
perubahan yang belum di-commit; file baru perlu di-stage agar ikut. Jika ada
penghapusan/rename file source, gunakan salinan source baru agar file lama
tidak ikut teruji. `.gitattributes` menetapkan LF untuk Elixir/HEEx agar
formatter tidak menghasilkan perubahan whitespace berbeda antar-OS.

## Hasil verifikasi 2026-11-12

- Debian 13, Elixir 1.19.5, OTP 27.3.4.1, PostgreSQL 17.11, `libheif` 1.23.6.
  Patch OTP distro berbeda dari pin 27.3.4.3; pengujian ini bukan sertifikasi
  image release production dengan pin tersebut.
- `mix precommit`: 234 test dan 7 doctest, 0 kegagalan pada sepuluh app umbrella.
- Bootstrap database baru dan migrasi berhasil sebelum suite dimulai.
- Test RAG berhasil mengekstrak file teks menggunakan NIF Xberg sebenarnya.
- HTTP startup pada port sementara `4011`: `GET /` mengembalikan 200 dan
  branding JosJob CMS; `GET /api/jobs` tanpa token mengembalikan 401.
- Database produksi/development dan file credential lokal tidak diubah.

Suite masih mengeluarkan warning runtime yang sudah ada terkait notifikasi
Ash dalam transaksi serta beberapa warning kode test. Warning tersebut tidak
disembunyikan atau diubah menjadi skip; seluruh test tetap dijalankan.
