defmodule JosjobWeb.Plugs.CmsPasswordLoginGate do
  @moduledoc """
  TEMPORARY — gate runtime untuk login email/password CMS (lihat strategi
  `password` di `Josjob.Accounts.User`).

  Rute `/auth/user/password/*` hanya dilayani bila flag `:cms_password_login`
  menyala (`CMS_PASSWORD_LOGIN=true` di envs/.env, default mati). Bila mati,
  permintaan dijawab 404 persis seperti `AshAuthentication.Phoenix.StrategyRouter`
  saat tidak ada rute yang cocok, sehingga endpoint password tidak bisa
  dipakai tanpa flag — strategi yang ter-compile tidak berarti endpoint-nya
  hidup.

  Rute Google (`/auth/user/google/*`) selalu diteruskan tanpa gate.

  HAPUS plug ini bersama strategi password + form login setelah Google OAuth
  jalan dan akun seed bisa sign-in Google.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{path_info: ["user", "password" | _]} = conn, opts) do
    if Application.get_env(:josjob, :cms_password_login, false) do
      AshAuthentication.Phoenix.StrategyRouter.call(conn, opts)
    else
      conn
      |> put_status(:not_found)
      |> Phoenix.Controller.json(%{error: "Not Found"})
      |> halt()
    end
  end

  def call(conn, opts), do: AshAuthentication.Phoenix.StrategyRouter.call(conn, opts)
end
