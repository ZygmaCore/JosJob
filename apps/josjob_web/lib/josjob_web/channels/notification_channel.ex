defmodule JosjobWeb.NotificationChannel do
  @moduledoc """
  Channel notifikasi per-user (contoh fondasi real-time).

  Topik: `user:notifications:<user_id>`. Hanya pemilik topik (user_id sama dengan
  yang terautentikasi di socket) yang boleh join. Logika notifikasi nyata (push
  event dari server) ditambah menyusul saat fiturnya dibangun.
  """
  use JosjobWeb, :channel

  @impl true
  def join("user:notifications:" <> user_id, _payload, socket) do
    if user_id == socket.assigns.user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Bukti koneksi dua arah; berguna juga untuk heartbeat sederhana dari klien.
  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{message: "pong"}}, socket}
  end
end
