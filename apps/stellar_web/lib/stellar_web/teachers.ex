defmodule StellarWeb.Teachers do
  @moduledoc """
  Query bersama "siapa itu teacher": user ber-membership aktif di sebuah org yang
  mengemban role `key == "teacher"` — role milik org tsb ATAU role global
  (`organization_id` nil, "Global (semua org)" di menu Roles). Satu sumber
  kebenaran untuk ClassLive (dropdown pengajar, kolom Instructor) dan
  TeacherLive (menu Teachers).
  """
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.Membership
  alias Stellar.Rbac.{MembershipRole, Role}

  @doc "User ber-role teacher. `org_id` nil = semua org (superuser)."
  def teacher_users(org_id) do
    role_ids =
      Role
      |> teacher_role_query(org_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    with false <- role_ids == [],
         membership_ids when membership_ids != [] <- teacher_membership_ids(role_ids),
         user_ids when user_ids != [] <- active_user_ids(membership_ids, org_id) do
      User |> Ash.Query.filter(id in ^user_ids) |> Ash.read!(authorize?: false)
    else
      _ -> []
    end
  end

  @doc """
  Baris menu Teachers: satu entri per pasangan org+user (user bisa mengajar di
  lebih dari satu org), urut nama lalu email.
  """
  def teacher_rows(org_id) do
    role_ids =
      Role
      |> teacher_role_query(org_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    memberships =
      if role_ids == [] do
        []
      else
        Membership
        |> Ash.Query.filter(id in ^teacher_membership_ids(role_ids) and status == :active)
        |> then(fn q ->
          if org_id, do: Ash.Query.filter(q, organization_id == ^org_id), else: q
        end)
        |> Ash.read!(authorize?: false)
      end

    user_ids = memberships |> Enum.map(& &1.user_id) |> Enum.uniq()

    users_by_id =
      if user_ids == [],
        do: %{},
        else:
          User
          |> Ash.Query.filter(id in ^user_ids)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, &1})

    memberships
    |> Enum.map(&%{organization_id: &1.organization_id, user: users_by_id[&1.user_id]})
    |> Enum.uniq_by(&{&1.organization_id, &1.user.id})
    |> Enum.sort_by(&{&1.user.full_name, to_string(&1.user.email)})
  end

  @doc "Set {organization_id, user_id} pengajar aktif untuk org yang muncul di list class."
  def teacher_pairs(classes) do
    org_ids = classes |> Enum.map(& &1.organization_id) |> Enum.uniq()

    role_ids =
      Role
      |> Ash.Query.filter(
        key == "teacher" and (organization_id in ^org_ids or is_nil(organization_id))
      )
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if role_ids == [] do
      MapSet.new()
    else
      Membership
      |> Ash.Query.filter(id in ^teacher_membership_ids(role_ids) and status == :active)
      |> Ash.read!(authorize?: false)
      |> MapSet.new(&{&1.organization_id, &1.user_id})
    end
  end

  defp teacher_role_query(query, nil), do: Ash.Query.filter(query, key == "teacher")

  defp teacher_role_query(query, org_id),
    do:
      Ash.Query.filter(
        query,
        key == "teacher" and (organization_id == ^org_id or is_nil(organization_id))
      )

  defp teacher_membership_ids(role_ids) do
    MembershipRole
    |> Ash.Query.filter(role_id in ^role_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.membership_id)
    |> Enum.uniq()
  end

  defp active_user_ids(membership_ids, org_id) do
    Membership
    |> Ash.Query.filter(id in ^membership_ids and status == :active)
    |> then(fn q -> if org_id, do: Ash.Query.filter(q, organization_id == ^org_id), else: q end)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
  end
end
