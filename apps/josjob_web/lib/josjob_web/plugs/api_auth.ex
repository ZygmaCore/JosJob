defmodule JosjobWeb.Plugs.ApiAuth do
  @moduledoc """
  Autentikasi API klien via Bearer **access token** (JWT ash_authentication).

  Memverifikasi tanda tangan token (`AshAuthentication.Jwt.verify/2`), menolak
  refresh token, lalu memuat user ke `conn.assigns.current_user`. Bila gagal,
  membalas 401 dan menghentikan pipeline.
  """
  import Plug.Conn

  alias AshAuthentication.Jwt
  alias Josjob.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims, _resource} <- Jwt.verify(token, :josjob),
         :ok <- ensure_access_token(claims),
         {:ok, user} <- AshAuthentication.subject_to_user(claims["sub"], User) do
      assign(conn, :current_user, user)
    else
      _ -> unauthorized(conn)
    end
  end

  defp ensure_access_token(%{"token_use" => "refresh"}), do: {:error, :refresh_token}
  defp ensure_access_token(_claims), do: :ok

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "unauthorized"})
    |> halt()
  end
end
