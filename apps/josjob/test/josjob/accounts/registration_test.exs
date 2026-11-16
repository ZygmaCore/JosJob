defmodule Josjob.Accounts.RegistrationTest do
  @moduledoc "Work-email rule for Corporation/Institution accounts (see EmailDomains)."
  use Josjob.DataCase, async: false

  alias Josjob.Accounts.User

  defp register(attrs) do
    User
    |> Ash.Changeset.for_create(:register_with_email, attrs)
    |> Ash.create(authorize?: false)
  end

  defp base(email, type),
    do: %{email: email, full_name: "Test User", password: "password123", account_type: type}

  defp email_error?(%{errors: errors}),
    do: Enum.any?(errors, fn e -> Map.get(e, :field) == :email end)

  describe "register_with_email — Corporation/Institution must use a work email" do
    test "personal account accepts a free email" do
      assert {:ok, user} = register(base("alex@gmail.com", :personal))
      assert user.account_type == :personal
    end

    test "personal account accepts a work email too" do
      assert {:ok, _} = register(base("alex@acme.com", :personal))
    end

    test "organization account accepts a work email" do
      assert {:ok, user} = register(base("hr@acme.com", :organization))
      assert user.account_type == :organization
    end

    test "organization account rejects a free email, on the :email field" do
      assert {:error, error} = register(base("hr@gmail.com", :organization))
      assert email_error?(error)
    end

    test "organization rejection is case-insensitive on the domain" do
      assert {:error, error} = register(base("HR@GMAIL.COM", :organization))
      assert email_error?(error)
    end

    test "organization rejects a trailing-dot free domain (canonicalized)" do
      assert {:error, error} = register(base("hr@gmail.com.", :organization))
      assert email_error?(error)
    end

    test "organization rejects an unparseable email domain" do
      assert {:error, error} = register(base("a@b@gmail.com", :organization))
      assert email_error?(error)
    end

    test "account_type accepts the string form from the JSON API" do
      assert {:error, _} = register(base("hr@gmail.com", "organization"))
      assert {:ok, user} = register(base("hr@acme.com", "organization"))
      assert user.account_type == :organization
    end

    test "an omitted account_type is left unset and accepts any email" do
      attrs = %{email: "x@gmail.com", full_name: "X", password: "password123"}
      assert {:ok, user} = register(attrs)
      assert is_nil(user.account_type)
    end
  end

  describe "one email → one account, type locked (rules 3 & 4)" do
    test "an email registered as organization cannot be reused for personal" do
      assert {:ok, _} = register(base("owner@acme.com", :organization))
      assert {:error, _} = register(base("owner@acme.com", :personal))
    end

    test "an email registered as personal cannot be reused for organization" do
      assert {:ok, _} = register(base("solo@acme.com", :personal))
      assert {:error, _} = register(base("solo@acme.com", :organization))
    end
  end

  describe "set_account_type (Google / onboarding path)" do
    setup do
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:upsert_with_google_claims, %{
          email: "person@gmail.com",
          full_name: "Person"
        })
        |> Ash.create(authorize?: false)

      %{user: user}
    end

    test "choosing organization with a free email is rejected", %{user: user} do
      assert {:error, error} =
               user
               |> Ash.Changeset.for_update(:set_account_type, %{account_type: :organization})
               |> Ash.update(authorize?: false)

      assert email_error?(error)
    end

    test "choosing personal is always allowed", %{user: user} do
      assert {:ok, updated} =
               user
               |> Ash.Changeset.for_update(:set_account_type, %{account_type: :personal})
               |> Ash.update(authorize?: false)

      assert updated.account_type == :personal
    end
  end

  describe "account type is locked once set" do
    test "an already-set type cannot be flipped (error on :account_type)" do
      {:ok, personal} = register(base("dev@acme.com", :personal))

      assert {:error, %{errors: errors}} =
               personal
               |> Ash.Changeset.for_update(:set_account_type, %{account_type: :organization})
               |> Ash.update(authorize?: false)

      assert Enum.any?(errors, fn e -> Map.get(e, :field) == :account_type end)
    end

    test "re-setting the same type is a harmless no-op" do
      {:ok, personal} = register(base("dev2@acme.com", :personal))

      assert {:ok, updated} =
               personal
               |> Ash.Changeset.for_update(:set_account_type, %{account_type: :personal})
               |> Ash.update(authorize?: false)

      assert updated.account_type == :personal
    end

    test "a Google user with a work email may become an organization" do
      {:ok, corp} =
        User
        |> Ash.Changeset.for_create(:upsert_with_google_claims, %{
          email: "founder@startup.io",
          full_name: "Founder"
        })
        |> Ash.create(authorize?: false)

      assert {:ok, updated} =
               corp
               |> Ash.Changeset.for_update(:set_account_type, %{account_type: :organization})
               |> Ash.update(authorize?: false)

      assert updated.account_type == :organization
    end
  end
end
