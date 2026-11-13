defmodule JosjobWeb.AuthController do
  use JosjobWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    # Superuser atau punya membership aktif -> dashboard; selain itu -> home.
    return_to =
      if Josjob.Authz.member?(user) do
        ~p"/dashboard"
      else
        ~p"/"
      end

    conn
    |> store_in_session(user)
    |> put_flash(:info, "Welcome back!")
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    require Logger

    Logger.error(
      "[Auth failure] activity=#{inspect(activity)} reason=#{inspect(reason, limit: :infinity)}"
    )

    conn
    |> put_flash(:error, "Authentication failed.")
    |> redirect(to: ~p"/")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:josjob)
    |> put_flash(:info, "Signed out successfully.")
    |> redirect(to: ~p"/")
  end
end
