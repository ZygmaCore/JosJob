defmodule JosjobWeb.UserSocket do
  @moduledoc """
  Socket real-time terautentikasi JWT.

  Klien menyertakan JWT (terbitan ash_authentication) sebagai query param saat
  handshake:

      ws://HOST/socket/websocket?token=<jwt>

  Token diverifikasi lalu user dimuat & disimpan di assigns; koneksi ditolak
  bila token hilang/invalid/kadaluarsa.
  """
  use Phoenix.Socket

  require Logger

  alias Josjob.Accounts.User

  # Channel contoh. Channel lain (progress/chat/quiz/ai_assistant) menyusul saat
  # fiturnya dibangun.
  channel("user:notifications:*", JosjobWeb.NotificationChannel)

  # Live streaming (WebRTC via Cloudflare Realtime SFU) — signaling per-room.
  channel("live_room:*", JosjobWeb.LiveRoomChannel)

  @impl true
  def connect(params, socket, _connect_info) do
    with token when is_binary(token) and token != "" <- Map.get(params, "token"),
         {:ok, %{"sub" => subject}, _claims} <-
           AshAuthentication.Jwt.verify(token, :josjob),
         {:ok, user} <- AshAuthentication.subject_to_user(subject, User) do
      socket =
        socket
        |> assign(:current_user, user)
        |> assign(:user_id, user.id)
        |> assign(:is_superuser, user.is_superuser)

      {:ok, socket}
    else
      nil ->
        Logger.warning("Socket ditolak: token tidak ada")
        :error

      "" ->
        Logger.warning("Socket ditolak: token kosong")
        :error

      {:error, reason} ->
        Logger.warning("Socket ditolak: token invalid (#{inspect(reason)})")
        :error

      other ->
        Logger.warning("Socket ditolak: verifikasi gagal (#{inspect(other)})")
        :error
    end
  end

  # Identitas socket per-user -> memungkinkan force-disconnect semua socket user
  # (mis. saat logout/ban) via `JosjobWeb.Endpoint.broadcast("users_socket:<id>", "disconnect", %{})`.
  @impl true
  def id(socket), do: "users_socket:#{socket.assigns.user_id}"
end
