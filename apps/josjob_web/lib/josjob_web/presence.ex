defmodule JosjobWeb.Presence do
  @moduledoc """
  `Phoenix.Presence` untuk sesi live streaming — melacak peserta per-room
  (topik `live_room:<room_id>`).

  Meta tiap peserta membawa mekanisme discovery: `sfu_session_id` + daftar
  `tracks` yang dipublish, sehingga subscriber tahu track (`trackName`) apa yang
  harus di-pull dari SFU untuk peserta itu. Dikelola oleh `JosjobWeb.LiveRoomChannel`.
  """
  use Phoenix.Presence,
    otp_app: :josjob_web,
    pubsub_server: Josjob.PubSub
end
