defmodule Stellar.Accounts.OnboardingSyncTest do
  @moduledoc "Onboarding.Sync: proyeksi jawaban -> UserDetail (personal) / Organization (org)."
  use Stellar.DataCase, async: false

  require Ash.Query

  alias Stellar.Accounts.{Onboarding, User, UserDetail}
  alias Stellar.Orgs.Organization

  defp create_user(email, account_type) do
    User
    |> Ash.Changeset.for_create(:register_with_email, %{
      email: email,
      full_name: "Test User",
      password: "password123",
      account_type: account_type
    })
    |> Ash.create!(authorize?: false)
  end

  test "personal (worker/graduate) -> UserDetail resume/education/interest" do
    user = create_user("worker@gmail.com", "personal")

    answers = %{
      "employments" => [
        %{
          "name" => "Acme Co",
          "position" => "Welder",
          "industry" => "Manufacturing",
          "from" => %{"month" => 1, "year" => 2020},
          "to" => %{"month" => 6, "year" => 2022}
        }
      ],
      "skills" => ["Welding", "Safety"],
      "educations" => [
        %{"degree" => "Diploma", "name" => "State Poly", "type" => "Vocational"}
      ],
      "achievements" => [
        %{"type" => "Certification", "name" => "Welding L2", "issuer" => "BNSP"}
      ],
      "hobbies" => ["Chess"],
      "other_profession_ids" => []
    }

    assert :ok = Onboarding.Sync.project(user, answers)

    detail =
      UserDetail |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)

    assert [emp] = detail.resume.employments
    assert emp.name == "Acme Co"
    assert emp.position == "Welder"
    assert emp.from.year == 2020
    assert detail.resume.skills == ["Welding", "Safety"]

    assert [edu] = detail.education.formal
    assert edu.degree == "Diploma"
    assert [ach] = detail.education.achievements
    assert ach.name == "Welding L2"

    assert detail.interest.hobbies == ["Chess"]
  end

  test "organization (employer/coordinator) -> relational Organization, no UserDetail" do
    user = create_user("hr@acme.com", "organization")

    answers = %{"orgName" => "Acme Corp", "orgRole" => "HR Manager"}

    assert :ok = Onboarding.Sync.project(user, answers)

    org =
      Organization |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)

    assert org.name == "Acme Corp"
    assert org.additional_info == "HR Manager"

    # Org accounts don't populate the personal UserDetail projection.
    assert {:ok, nil} =
             UserDetail
             |> Ash.Query.filter(user_id == ^user.id)
             |> Ash.read_one(authorize?: false)
  end

  test "re-projecting is idempotent (upsert by user)" do
    user = create_user("grad@gmail.com", "personal")
    answers = %{"skills" => ["A"]}

    assert :ok = Onboarding.Sync.project(user, answers)
    assert :ok = Onboarding.Sync.project(user, %{"skills" => ["A", "B"]})

    details = UserDetail |> Ash.Query.filter(user_id == ^user.id) |> Ash.read!(authorize?: false)
    assert length(details) == 1
    assert hd(details).resume.skills == ["A", "B"]
  end
end
