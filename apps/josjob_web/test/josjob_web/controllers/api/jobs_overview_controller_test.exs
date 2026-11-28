defmodule JosjobWeb.Api.JobsOverviewControllerTest do
  use JosjobWeb.ConnCase, async: true
  import JosjobWeb.JobFixtures
  alias Josjob.Accounts.{Profile, User}
  alias Josjob.Orgs.Membership

  defp overview(conn, user, params \\ %{}),
    do:
      conn
      |> auth(user)
      |> get(~p"/api/me/jobs-overview", params)
      |> json_response(200)
      |> Map.fetch!("data")

  test "authentication and empty accounts return no invented metrics", %{conn: conn} do
    assert conn |> get(~p"/api/me/jobs-overview") |> json_response(401)
    data = overview(conn, user!())

    assert data["stats"] == %{
             "available_jobs" => 0,
             "remote_jobs" => 0,
             "full_time_jobs" => 0,
             "published_last_7_days" => 0
           }

    assert data["jobs"] == []
    assert data["profile"]["skill_count"] == 0

    assert data["capabilities"] == %{
             "matching" => false,
             "applications" => true,
             "interviews" => true
           }

    refute Map.has_key?(data["stats"], "applications")
    refute Map.has_key?(data["profile"], "strength")
  end

  test "counts public active listings across organizations while limiting previews",
       %{conn: conn} do
    owner = user!()
    learner = user!()
    org = organization!(owner)
    grant!(learner, org, "graduate")

    jobs =
      for i <- 1..8,
          do:
            job!(org, owner, %{
              "title" => "Active #{i}",
              "work_mode" => if(rem(i, 2) == 0, do: "remote", else: "onsite"),
              "employment_type" => if(i <= 3, do: "full-time", else: "part-time")
            })

    job!(org, owner, %{"status" => "draft"})
    job!(org, owner, %{"status" => "expired"})
    foreign = job!(organization!(owner, "Foreign"), owner)
    data = overview(conn, learner, %{"scope" => "manage", "organization_id" => org.id})

    assert data["stats"] == %{
             "available_jobs" => 9,
             "remote_jobs" => 4,
             "full_time_jobs" => 4,
             "published_last_7_days" => 9
           }

    assert length(data["jobs"]) == 6
    ids = Enum.map([foreign | jobs], & &1.id)
    assert Enum.all?(data["jobs"], &(&1["id"] in ids))
    assert Enum.all?(data["jobs"], &(not &1["can_manage"]))
    refute Enum.any?(data["jobs"], &Map.has_key?(&1, "match_score"))
    assert hd(data["jobs"])["id"] == foreign.id
    board = conn |> auth(learner) |> get(~p"/api/jobs") |> json_response(200)
    assert board["meta"]["total"] == data["stats"]["available_jobs"]
  end

  test "recent publication counts exclude old, unknown and future timestamps", %{conn: conn} do
    user = user!()
    org = organization!(user)
    grant!(user, org, "employer")
    now = DateTime.utc_now()

    for date <- [
          DateTime.add(now, -8 * 86400),
          nil,
          DateTime.add(now, 86400),
          DateTime.add(now, -3600)
        ] do
      job!(org, user)
      |> Ash.Changeset.for_update(:update, %{})
      |> Ash.Changeset.force_change_attribute(:posted_at, date)
      |> Ash.update!(authorize?: false)
    end

    job!(org, user, %{"status" => "draft"})
    data = overview(conn, user)
    assert data["stats"]["available_jobs"] == 4
    assert data["stats"]["published_last_7_days"] == 1
    assert Enum.all?(data["jobs"], &(&1["status"] == "active"))
  end

  test "unprovisioned accounts and superusers see active listings with different management capabilities",
       %{conn: conn} do
    owner = user!()
    member = user!()
    org = organization!(owner)

    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: member.id,
      organization_id: org.id,
      status: :active
    })
    |> Ash.create!(authorize?: false)

    job = job!(org, owner)
    job!(org, owner, %{"status" => "draft"})
    assert overview(conn, member)["stats"]["available_jobs"] == 1
    assert [%{"can_manage" => false}] = overview(conn, member)["jobs"]

    admin =
      User
      |> Ash.Changeset.for_create(:create, %{
        email: "overview-admin#{System.unique_integer([:positive])}@example.com",
        full_name: "Admin",
        is_superuser: true
      })
      |> Ash.create!(authorize?: false)

    data = overview(conn, admin)
    assert data["stats"]["available_jobs"] == 1
    assert [%{"id" => id, "can_manage" => true}] = data["jobs"]
    assert id == job.id
  end

  test "profile facts are caller-owned, saved data and never certification verification", %{
    conn: conn
  } do
    user = user!()
    other = user!()

    answers = %{
      "skills" => [" Elixir ", "SQL", "elixir", nil, 4, ""],
      "employments" => [%{"name" => "Company"}, %{"position" => "Developer"}, %{}, nil],
      "educations" => [%{"name" => "University"}, %{"name" => "  "}],
      "achievements" => [%{"type" => "Certification", "name" => "Safety"}]
    }

    Profile
    |> Ash.Changeset.for_create(:upsert_answers, %{user_id: user.id, answers: answers})
    |> Ash.create!(authorize?: false)

    {:ok, _} =
      JosjobLrn.Certificates.add_certificate(user, %{
        "title" => "First aid",
        "issuer" => "Provider"
      })

    data = overview(conn, user)
    assert data["profile"]["skills"] == ["Elixir", "SQL"]
    assert data["profile"]["skill_count"] == 2
    assert data["profile"]["experience_count"] == 2
    assert data["profile"]["education_count"] == 1
    assert data["profile"]["certificates_saved"] == 2
    refute Map.has_key?(data["profile"], "certifications_verified")
    other_data = overview(conn, other, %{"user_id" => user.id})
    assert other_data["profile"]["skills"] == []
    assert other_data["profile"]["certificates_saved"] == 0
  end

  test "malformed optional onboarding sections do not become fabricated profile facts", %{
    conn: conn
  } do
    user = user!()

    Profile
    |> Ash.Changeset.for_create(:upsert_answers, %{
      user_id: user.id,
      answers: %{"skills" => %{}, "employments" => "unknown", "educations" => nil}
    })
    |> Ash.create!(authorize?: false)

    profile = overview(conn, user)["profile"]
    assert profile["skills"] == []
    assert profile["experience_count"] == 0
    assert profile["education_count"] == 0
  end
end
