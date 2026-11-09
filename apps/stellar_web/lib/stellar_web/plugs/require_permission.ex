defmodule StellarWeb.Plugs.RequirePermission do
  @moduledoc """
  Gate route berbasis permission. Lolos bila `conn.assigns.permissions`
  mengizinkan permission ini (superuser `:all` selalu lolos); jika tidak,
  flash + redirect ke `/`. Butuh `AssignActiveOrg` sudah jalan (di `:browser`).

  Dipakai lewat pipeline, mis. `plug StellarWeb.Plugs.RequirePermission, "members:manage"`.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(permission) when is_binary(permission) or is_list(permission), do: permission

  def call(conn, permission) do
    if StellarWeb.Perms.can?(conn.assigns[:permissions], permission) do
      conn
    else
      conn
      |> put_flash(:error, "You don't have permission to access that page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
