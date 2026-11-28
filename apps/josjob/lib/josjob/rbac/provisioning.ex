defmodule Josjob.Rbac.Provisioning do
  @moduledoc """
  Provisioning role/permission sistem ke sebuah organisasi — idempoten.

  Role sistem (mis. `"teacher"`) di-seed **per-organisasi** (lihat
  `Josjob.Release`; role punya `organization_id`). Saat superuser mengundang
  seorang teacher ke organisasi PILIHANNYA, role `"teacher"` mungkin belum ada di
  org itu. Modul ini menjamin role beserta permission-nya ada di org tsb sebelum
  ditautkan ke membership — memakai definisi kanonik dari `Josjob.Rbac.Catalog`
  agar tidak ada drift dengan hasil seed.
  """
  require Ash.Query

  alias Josjob.Rbac.{Catalog, Permission, Role, RolePermission}

  @doc """
  Pastikan permission `key` ada (upsert by key, metadata dari katalog). Return `Permission`.
  """
  def ensure_permission!(key) when is_binary(key) do
    {^key, category, description} =
      Catalog.permission(key) || raise ArgumentError, "unknown permission #{inspect(key)}"

    Permission
    |> Ash.Changeset.for_create(:create, %{key: key, category: category, description: description})
    |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_key)
  end

  @doc """
  Pastikan seluruh permission di katalog ada. Return jumlahnya.
  """
  def ensure_permissions! do
    Enum.each(Catalog.permissions(), fn {key, _cat, _desc} -> ensure_permission!(key) end)
    length(Catalog.permissions())
  end

  @doc """
  Jamin role sistem `role_key` ada di `org_id` beserta permission-nya (dari
  katalog). Idempoten. Return `Role`.
  """
  def ensure_org_role!(org_id, role_key) when is_binary(org_id) and is_binary(role_key) do
    {name, perm_keys} =
      Catalog.role(role_key) || raise ArgumentError, "unknown role #{inspect(role_key)}"

    role = upsert_org_role!(org_id, role_key, name)

    Enum.each(perm_keys, fn pk ->
      perm = ensure_permission!(pk)
      link_permission!(role.id, perm.id)
    end)

    role
  end

  # Role milik org tertentu. Idempoten (cari by org_id+key). display_name = name.
  defp upsert_org_role!(org_id, key, name) do
    case Role
         |> Ash.Query.filter(organization_id == ^org_id and key == ^key)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        Role
        |> Ash.Changeset.for_create(:create, %{
          key: key,
          name: name,
          display_name: name,
          is_system: true,
          organization_id: org_id
        })
        |> Ash.create!(authorize?: false)

      role ->
        role
    end
  end

  defp link_permission!(role_id, permission_id) do
    exists? =
      RolePermission
      |> Ash.Query.filter(role_id == ^role_id and permission_id == ^permission_id)
      |> Ash.read_one!(authorize?: false)

    unless exists? do
      RolePermission
      |> Ash.Changeset.for_create(:create, %{role_id: role_id, permission_id: permission_id})
      |> Ash.create!(authorize?: false)
    end
  end
end
