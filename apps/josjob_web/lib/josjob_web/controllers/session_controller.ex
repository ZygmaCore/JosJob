defmodule JosjobWeb.SessionController do
  @moduledoc """
  Halaman login (Google OAuth). Menampilkan tombol "Sign in with Google" yang
  mengarah ke alur redirect OAuth (`/auth/user/google`).

  TEMPORARY: bila flag `:cms_password_login` menyala
  (`CMS_PASSWORD_LOGIN=true`, default mati), halaman juga menampilkan form
  login email/password. Hapus form + flag ini setelah Google OAuth jalan.
  """
  use JosjobWeb, :controller

  def new(conn, _params) do
    conn
    |> put_layout(false)
    |> assign(
      :password_login_enabled,
      Application.get_env(:josjob, :cms_password_login, false)
    )
    |> assign(:password_form, Phoenix.Component.to_form(%{}, as: "user"))
    |> render(:new)
  end
end
