defmodule Josjob.Authz do
  @moduledoc """
  Helper otorisasi tingkat aplikasi (RBAC, web-layer).

  - `superuser?/1` — admin platform (`users.is_superuser`), OTORITATIF dari DB.
  - `member?/1` — superuser ATAU punya minimal satu membership `active`.
  - `active_org_id/2` — organisasi aktif user (nilai session bila valid, else
    membership aktif pertama).
  - `permissions_for/2` — MapSet key permission efektif user pada satu org
    (union `role_permissions` dari `membership_roles`). Tidak digabung lintas-org.
  - `can?/3` — superuser bypass; selain itu cek `permissions_for`.

  Enforcement lewat helper ini + plug (`RequirePermission`), bukan Ash policy.
  """
  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Orgs.Membership
  alias Josjob.Rbac.{MembershipRole, Role, RolePermission, Permission}

  def superuser?(%{id: id}) when is_binary(id) do
    case Ash.get(User, id, authorize?: false) do
      {:ok, %{is_superuser: true}} -> true
      _ -> false
    end
  end

  def superuser?(_), do: false

  def member?(user) do
    superuser?(user) or has_active_membership?(user)
  end

  @doc """
  True bila `user` punya minimal satu membership `active` yang mengemban role
  (sudah di-provision admin). Dasar "approved" untuk akun organisasi: sebuah
  akun korporasi baru bisa masuk dashboard setelah diberi keanggotaan+role.
  """
  def provisioned?(%{id: uid}) when is_binary(uid) do
    membership_ids =
      Membership
      |> Ash.Query.filter(user_id == ^uid and status == :active)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if membership_ids == [] do
      false
    else
      MembershipRole
      |> Ash.Query.filter(membership_id in ^membership_ids)
      |> Ash.read!(authorize?: false)
      |> Enum.any?()
    end
  end

  def provisioned?(_), do: false

  @doc "Organisasi aktif: pakai `session_value` bila user memang member aktif di sana; else membership aktif pertama; nil bila tak ada."
  def active_org_id(session_value, %{id: id}) when is_binary(id) do
    org_ids = active_org_ids(id)

    if is_binary(session_value) and session_value in org_ids,
      do: session_value,
      else: List.first(org_ids)
  end

  def active_org_id(_session_value, _user), do: nil

  @doc "Daftar %{id, name} organisasi tempat user member aktif (urut nama)."
  def member_orgs(%{id: uid}) when is_binary(uid) do
    Membership
    |> Ash.Query.filter(user_id == ^uid and status == :active)
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:organization], authorize?: false)
    |> Enum.map(&%{id: &1.organization_id, name: &1.organization.name})
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.name)
  end

  def member_orgs(_user), do: []

  @doc """
  Daftar key role sistem yang diemban user (union lintas semua membership aktif,
  tanpa mempedulikan org aktif). Dipakai klien untuk deteksi peran, mis.
  `"teacher"` → tampilkan dashboard/menu teacher.
  """
  def role_keys(%{id: uid}) when is_binary(uid) do
    membership_ids =
      Membership
      |> Ash.Query.filter(user_id == ^uid and status == :active)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    membership_ids
    |> role_ids_for()
    |> role_keys_for()
  end

  def role_keys(_), do: []

  @doc "MapSet key permission efektif user pada `org_id`."
  def permissions_for(%{id: uid}, org_id) when is_binary(uid) and is_binary(org_id) do
    membership_ids =
      Membership
      |> Ash.Query.filter(user_id == ^uid and organization_id == ^org_id and status == :active)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    role_ids = role_ids_for(membership_ids)
    permission_ids = permission_ids_for(role_ids)

    permission_keys(permission_ids)
  end

  def permissions_for(_user, _org_id), do: MapSet.new()

  @doc "Boleh melakukan `permission` pada `org_id`? Superuser selalu true."
  def can?(user, org_id, permission) do
    cond do
      superuser?(user) -> true
      is_binary(org_id) -> MapSet.member?(permissions_for(user, org_id), permission)
      true -> false
    end
  end

  # --- private ---

  defp has_active_membership?(%{id: id}) when is_binary(id) do
    Membership
    |> Ash.Query.filter(user_id == ^id and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  defp has_active_membership?(_), do: false

  defp active_org_ids(uid) do
    Membership
    |> Ash.Query.filter(user_id == ^uid and status == :active)
    |> Ash.Query.sort(created_at: :asc)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.organization_id)
  end

  defp role_ids_for([]), do: []

  defp role_ids_for(membership_ids) do
    MembershipRole
    |> Ash.Query.filter(membership_id in ^membership_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.role_id)
    |> Enum.uniq()
  end

  defp permission_ids_for([]), do: []

  defp permission_ids_for(role_ids) do
    RolePermission
    |> Ash.Query.filter(role_id in ^role_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.permission_id)
    |> Enum.uniq()
  end

  defp permission_keys([]), do: MapSet.new()

  defp permission_keys(permission_ids) do
    Permission
    |> Ash.Query.filter(id in ^permission_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.key)
    |> MapSet.new()
  end

  defp role_keys_for([]), do: []

  defp role_keys_for(role_ids) do
    Role
    |> Ash.Query.filter(id in ^role_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.key)
    |> Enum.uniq()
  end
end
