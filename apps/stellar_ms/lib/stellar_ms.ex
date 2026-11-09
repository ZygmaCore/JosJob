defmodule StellarMs do
  @moduledoc """
  Modul media streaming platform Stellar — ingest/transcode/HLS/CDN untuk video.

  Ini adalah API publik (provider-agnostic) dari app `:stellar_ms`. App lain
  (mis. `:stellar` seeder, `:stellar_web` controller) memanggil lewat modul ini,
  BUKAN implementasi provider di baliknya, sehingga provider bisa diganti tanpa
  menyentuh pemanggil.

  Provider saat ini: Cloudflare Stream (`StellarMs.CloudflareStream`).
  """

  defdelegate configured?(), to: StellarMs.CloudflareStream
  defdelegate create_direct_upload(opts \\ []), to: StellarMs.CloudflareStream
  defdelegate get_video(uid), to: StellarMs.CloudflareStream
  defdelegate upload_file(upload_url, path), to: StellarMs.CloudflareStream
  defdelegate normalize(video), to: StellarMs.CloudflareStream
  defdelegate verify_webhook(raw_body, sig_header), to: StellarMs.CloudflareStream
  defdelegate hls_url_for(uid), to: StellarMs.CloudflareStream
end
