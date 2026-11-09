defmodule StellarWeb.Plugs.RequireAdmin do
  @moduledoc """
  Hanya mengizinkan **superuser platform** (`users.is_superuser`) mengakses
  halaman admin. Status dibaca otoritatif dari DB (lihat `Stellar.Authz`).
  """
  import Plug.Conn
  import Phoenix.Controller
  use StellarWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if Stellar.Authz.superuser?(conn.assigns[:current_user]) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in as an administrator to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end
end
