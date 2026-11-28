# Demo seed runner — 1000 baris data sintetis di semua tabel yang bisa di-seed.
#
# Jalankan dari ROOT repo:
#
#     mix run apps/josjob/priv/repo/demo_seeds.exs
#
# Logika ada di `JosjobLrn.DemoSeed` (app :josjob_lrn, yang boleh depend
# :josjob). Dipanggil via `apply/3` — bukan `JosjobLrn.DemoSeed.seed()`
# langsung — supaya script ini tetap jalan walau :josjob_lrn belum ter-load
# saat script dievaluasi (pola yang sama dipakai `Josjob.Release.seed/0`
# untuk katalog).
#
# BEDA dengan `seeds.exs`: script ini TIDAK dipanggil otomatis oleh
# `mix ecto.setup` dan TIDAK dipanggil dari `Josjob.Release.seed/0`.
# Data demo hanya dibuat bila seseorang menjalankan script ini secara eksplisit.
# Aman di-run ulang (idempotent, deterministik).
if Code.ensure_loaded?(JosjobLrn.DemoSeed) and
     function_exported?(JosjobLrn.DemoSeed, :seed, 0) do
  apply(JosjobLrn.DemoSeed, :seed, [])
else
  raise """
  JosjobLrn.DemoSeed belum ter-load. Jalankan dari root repo (umbrella),
  bukan dari dalam apps/josjob:

      mix run apps/josjob/priv/repo/demo_seeds.exs
  """
end
