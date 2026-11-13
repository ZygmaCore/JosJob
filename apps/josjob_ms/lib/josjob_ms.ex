defmodule JosjobMs do
  @moduledoc """
  Modul media streaming platform Josjob — ingest/transcode/HLS/CDN untuk video.

  Ini adalah API publik (provider-agnostic) dari app `:josjob_ms`. App lain
  (mis. `:josjob` seeder, `:josjob_web` controller) memanggil lewat modul ini,
  BUKAN implementasi provider di baliknya, sehingga provider bisa diganti tanpa
  menyentuh pemanggil.

  Provider saat ini: Cloudflare Stream (`JosjobMs.CloudflareStream`).
  """

  defdelegate configured?(), to: JosjobMs.CloudflareStream
  defdelegate create_direct_upload(opts \\ []), to: JosjobMs.CloudflareStream
  defdelegate get_video(uid), to: JosjobMs.CloudflareStream
  defdelegate upload_file(upload_url, path), to: JosjobMs.CloudflareStream
  defdelegate normalize(video), to: JosjobMs.CloudflareStream
  defdelegate verify_webhook(raw_body, sig_header), to: JosjobMs.CloudflareStream
  defdelegate hls_url_for(uid), to: JosjobMs.CloudflareStream
end
