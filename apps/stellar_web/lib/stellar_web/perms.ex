defmodule StellarWeb.Perms do
  @moduledoc """
  Cek izin dari nilai `conn.assigns.permissions` (`:all` untuk superuser, atau
  `MapSet` key permission). Dipakai plug, controller, dan template.
  """
  def can?(:all, _permission), do: true

  # Daftar permission = lolos bila punya SALAH SATU (mis. read ATAU manage).
  def can?(permissions, list) when is_list(list),
    do: Enum.any?(list, &can?(permissions, &1))

  def can?(%MapSet{} = permissions, permission), do: MapSet.member?(permissions, permission)
  def can?(_permissions, _permission), do: false
end
