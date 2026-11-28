defmodule JosjobWeb.Plugs.RequireMember do
  @moduledoc """
  Mengizinkan akses area member (mis. `/dashboard`) untuk **superuser** ATAU
  user yang punya minimal satu membership `active` (lihat `Josjob.Authz`).
  """
  import Plug.Conn
  import Phoenix.Controller
  use JosjobWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if Josjob.Authz.member?(conn.assigns[:current_user]) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end
end
