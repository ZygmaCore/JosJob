defmodule StellarMs.Storage do
  @moduledoc """
  Facade object storage (S3-compatible) — API publik provider-agnostic untuk
  upload file non-video (pdf/doc/dll). Pemanggil (mis. `:stellar_web` controller)
  memakai modul ini, BUKAN implementasi provider di baliknya.

  Dipisah dari facade `StellarMs` (video) & `StellarMs.Realtime` (live) supaya
  `configured?/0` tidak bertabrakan (tiap produk punya kredensialnya sendiri).

  Provider saat ini: `StellarMs.S3Storage` (Cloudflare R2 / AWS S3 / MinIO).
  """

  defdelegate configured?(), to: StellarMs.S3Storage
  defdelegate create_presigned_upload(opts \\ []), to: StellarMs.S3Storage
  defdelegate public_url_for(key), to: StellarMs.S3Storage
end
