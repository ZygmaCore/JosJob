defmodule JosjobMs.Storage do
  @moduledoc """
  Facade object storage (S3-compatible) — API publik provider-agnostic untuk
  upload file non-video (pdf/doc/dll). Pemanggil (mis. `:josjob_web` controller)
  memakai modul ini, BUKAN implementasi provider di baliknya.

  Dipisah dari facade `JosjobMs` (video) & `JosjobMs.Realtime` (live) supaya
  `configured?/0` tidak bertabrakan (tiap produk punya kredensialnya sendiri).

  Provider saat ini: `JosjobMs.S3Storage` (Cloudflare R2 / AWS S3 / MinIO).
  """

  defdelegate configured?(), to: JosjobMs.S3Storage
  defdelegate create_presigned_upload(opts \\ []), to: JosjobMs.S3Storage
  defdelegate public_url_for(key), to: JosjobMs.S3Storage
end
