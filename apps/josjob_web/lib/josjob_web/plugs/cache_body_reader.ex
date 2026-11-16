defmodule JosjobWeb.Plugs.CacheBodyReader do
  @moduledoc """
  Body reader untuk `Plug.Parsers` yang menyimpan raw body HANYA untuk endpoint
  webhook Stripe (butuh byte mentah demi verifikasi signature). Request lain tidak
  di-cache agar tidak membebani memori.

  Dipasang di `JosjobWeb.Endpoint` via opsi `:body_reader` pada `Plug.Parsers`.
  Raw body tersimpan sebagai iodata terbalik di `conn.assigns.raw_body`.
  """
  @webhook_paths ["/api/webhooks/stripe", "/api/webhooks/cloudflare-stream"]

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    conn =
      if conn.request_path in @webhook_paths do
        update_in(conn.assigns[:raw_body], &[body | &1 || []])
      else
        conn
      end

    {:ok, body, conn}
  end
end
