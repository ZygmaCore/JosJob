# Script for populating the database. Run with:
#
#     mix run priv/repo/seeds.exs   (atau lewat `mix ecto.setup`)
#
# Membuat SATU superuser awal untuk akses admin/CMS. Login FULL Google OAuth:
# user ini dibuat TANPA password; saat pemiliknya login via Google (email cocok),
# `register_with_google` meng-upsert record ini dan role superuser tetap
# dipertahankan (upsert tidak menimpa :roles). Email dari SEED_SUPERUSER_EMAIL.
#
# Logika seed berada di Stellar.Release.seed/0 agar SATU sumber, dipakai baik di
# dev (mix) maupun di release/deploy (bin/seed). Idempoten.
Stellar.Release.seed()
