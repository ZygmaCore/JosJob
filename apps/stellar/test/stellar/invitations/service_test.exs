defmodule Stellar.Invitations.ServiceTest do
  @moduledoc "Alur undangan teacher: buat/kirim, reuse+resend, accept → provision."
  use Stellar.DataCase, async: false

  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Invitations.{Invitation, Service}
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Role}

  setup do
    owner = create_user!("owner@example.com")

    org =
      Organization
      |> Ash.Changeset.for_create(:create, %{
        name: "Org #{System.unique_integer([:positive])}",
        user_id: owner.id
      })
      |> Ash.create!(authorize?: false)

    %{owner: owner, org: org}
  end

  describe "invite/1" do
    test "creates a pending teacher invitation with a token", %{org: org, owner: owner} do
      assert {:ok, invite} =
               Service.invite(%{
                 email: "teach@example.com",
                 organization_id: org.id,
                 invited_by_id: owner.id
               })

      assert invite.status == :pending
      assert invite.role_key == "teacher"
      assert to_string(invite.email) == "teach@example.com"
      assert is_binary(invite.token) and invite.token != ""
      assert invite.invited_by_id == owner.id
    end

    test "rejects a malformed email", %{org: org} do
      assert {:error, :invalid_email} = Service.invite(%{email: "nope", organization_id: org.id})
    end

    test "re-inviting the same email+org reuses the invite (resend), no duplicate", %{org: org} do
      assert {:ok, i1} = Service.invite(%{email: "dup@example.com", organization_id: org.id})
      assert {:ok, i2} = Service.invite(%{email: "dup@example.com", organization_id: org.id})

      assert i1.id == i2.id
      assert i2.resend_count == 1

      count =
        Invitation
        |> Ash.Query.filter(email == "dup@example.com")
        |> Ash.read!(authorize?: false)
        |> length()

      assert count == 1
    end
  end

  describe "accept/2 (new user)" do
    test "provisions user + active membership + teacher role, marks accepted, logs in", %{
      org: org
    } do
      {:ok, invite} = Service.invite(%{email: "new@example.com", organization_id: org.id})

      assert {:ok, %{user: user, tokens: tokens, new: true}} =
               Service.accept(invite.token, %{full_name: "New Teacher", password: "password123"})

      assert to_string(user.email) == "new@example.com"
      # teacher diundang admin → lewati onboarding
      assert user.mandatory_completed == true
      assert user.onboarding_progress == 100
      assert is_binary(tokens.token) and is_binary(tokens.refresh_token)

      membership =
        Membership
        |> Ash.Query.filter(user_id == ^user.id and organization_id == ^org.id)
        |> Ash.read_one!(authorize?: false)

      assert membership.status == :active

      teacher_role =
        Role
        |> Ash.Query.filter(organization_id == ^org.id and key == "teacher")
        |> Ash.read_one!(authorize?: false)

      assert teacher_role
      assert teacher_role.is_system == true

      links =
        MembershipRole
        |> Ash.Query.filter(membership_id == ^membership.id and role_id == ^teacher_role.id)
        |> Ash.read!(authorize?: false)

      assert length(links) == 1

      reloaded = Ash.get!(Invitation, invite.id, authorize?: false)
      assert reloaded.status == :accepted
      assert reloaded.accepted_user_id == user.id

      assert "teacher" in Stellar.Authz.role_keys(user)
    end

    test "token can only be accepted once", %{org: org} do
      {:ok, invite} = Service.invite(%{email: "once@example.com", organization_id: org.id})

      assert {:ok, _} =
               Service.accept(invite.token, %{full_name: "Once", password: "password123"})

      assert {:error, :already_accepted} = Service.get_by_token(invite.token)
    end
  end

  describe "accept/2 (existing user)" do
    test "provisions role without auto-login for an email that already has an account", %{
      org: org
    } do
      _existing = create_user!("has@example.com")
      {:ok, invite} = Service.invite(%{email: "has@example.com", organization_id: org.id})

      assert {:ok, %{user: user, tokens: nil, new: false}} =
               Service.accept(invite.token, %{full_name: "Ignored", password: "password123"})

      assert "teacher" in Stellar.Authz.role_keys(user)
    end
  end

  describe "get_by_token/1" do
    test "returns error for an expired invitation", %{org: org} do
      # ttl_days negatif → expires_at di masa lampau.
      {:ok, invite} =
        Invitation
        |> Ash.Changeset.for_create(:create, %{
          email: "exp@example.com",
          organization_id: org.id,
          ttl_days: -1
        })
        |> Ash.create(authorize?: false)

      assert {:error, :expired} = Service.get_by_token(invite.token)
    end

    test "returns not_found for an unknown token" do
      assert {:error, :not_found} = Service.get_by_token("does-not-exist")
    end
  end

  defp create_user!(email) do
    User
    |> Ash.Changeset.for_create(:register_with_email, %{
      email: email,
      full_name: "User",
      password: "password123"
    })
    |> Ash.create!(authorize?: false)
  end
end
