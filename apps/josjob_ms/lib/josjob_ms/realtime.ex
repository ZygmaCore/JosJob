defmodule JosjobMs.Realtime do
  @moduledoc """
  API publik (provider-agnostic) untuk realtime live streaming — SFU fan-out +
  TURN NAT traversal — sesi kelas / 1-on-1 / coaching. Bagian dari app `:josjob_ms`.

  Ini seam sejajar dengan `JosjobMs` (Cloudflare Stream/VOD): keduanya klien
  media Cloudflare namun produk berbeda, jadi realtime punya facade sendiri agar
  `configured?/0` tidak bentrok dengan status Stream.

  App lain (mis. `JosjobWeb.LiveRoomChannel`) memanggil lewat modul ini, BUKAN
  implementasi provider di baliknya, sehingga provider bisa diganti tanpa
  menyentuh pemanggil. Provider saat ini: Cloudflare Realtime
  (lihat `JosjobMs.CloudflareRealtime`).
  """

  alias JosjobMs.CloudflareRealtime

  defdelegate configured?(), to: CloudflareRealtime
  defdelegate turn_configured?(), to: CloudflareRealtime
  defdelegate ice_servers(opts \\ []), to: CloudflareRealtime
  defdelegate new_session(), to: CloudflareRealtime
  defdelegate publish_tracks(session_id, offer_sdp, tracks), to: CloudflareRealtime
  defdelegate pull_tracks(session_id, remote_tracks), to: CloudflareRealtime
  defdelegate renegotiate(session_id, answer_sdp), to: CloudflareRealtime
  defdelegate close_tracks(session_id, mids, force \\ true), to: CloudflareRealtime
  defdelegate session_state(session_id), to: CloudflareRealtime
end
