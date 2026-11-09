defmodule StellarWeb.SessionController do
  @moduledoc """
  Halaman login (Google OAuth). Menampilkan tombol "Sign in with Google" yang
  mengarah ke alur redirect OAuth (`/auth/user/google`).
  """
  use StellarWeb, :controller

  def new(conn, _params) do
    conn
    |> put_layout(false)
    |> render(:new)
  end
end
