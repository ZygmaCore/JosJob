defmodule StellarWeb.JobFixtures do
  @moduledoc false
  alias Stellar.Accounts.{Tokens, User}
  alias Stellar.Orgs.{Organization, Membership}
  alias Stellar.Rbac.{MembershipRole, Provisioning}
  alias StellarJob.Job

  def user! do
    User
    |> Ash.Changeset.for_create(:register_with_email, %{
      email: "jobs-#{System.unique_integer([:positive])}@example.com",
      full_name: "Job tester",
      password: "password123"
    })
    |> Ash.create!(authorize?: false)
  end

  def organization!(owner, name \\ "Example employer") do
    Organization
    |> Ash.Changeset.for_create(:create, %{name: name, user_id: owner.id})
    |> Ash.create!(authorize?: false)
  end

  def grant!(user, org, key) do
    role = Provisioning.ensure_org_role!(org.id, key)

    membership =
      Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: user.id,
        organization_id: org.id,
        status: :active
      })
      |> Ash.create!(authorize?: false)

    MembershipRole
    |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
    |> Ash.create!(authorize?: false)

    membership
  end

  def attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "title" => "Junior developer",
        "description" => "Build useful software.",
        "location" => "Bandung",
        "industry" => "Technology",
        "employment_type" => "full-time",
        "work_mode" => "hybrid",
        "requirements" => ["Elixir", "SQL"],
        "salary_min" => 5_000_000,
        "salary_max" => 8_000_000,
        "currency" => "IDR"
      },
      overrides
    )
  end

  def job!(org, creator, overrides \\ %{}) do
    Job
    |> Ash.Changeset.for_create(:create, attrs(Map.merge(%{"status" => "active"}, overrides)))
    |> Ash.Changeset.force_change_attribute(:organization_id, org.id)
    |> Ash.Changeset.force_change_attribute(:created_by, creator.id)
    |> Ash.Changeset.force_change_attribute(:posted_at, DateTime.utc_now())
    |> Ash.create!(authorize?: false)
  end

  def auth(conn, user) do
    {:ok, tokens} = Tokens.issue_pair(user)
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{tokens.token}")
  end
end
