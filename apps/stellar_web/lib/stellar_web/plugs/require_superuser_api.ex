defmodule StellarWeb.Plugs.RequireSuperuserApi do
  @moduledoc """
  Gate API **superuser** (JSON). Dipasang SETELAH `StellarWeb.Plugs.ApiAuth`
  (yang memuat `conn.assigns.current_user` dari Bearer token). Lolos hanya bila
  user `is_superuser`; selain itu 403 + halt.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{is_superuser: true} ->
        conn

      _ ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{error: "forbidden"})
        |> halt()
    end
  end
end
