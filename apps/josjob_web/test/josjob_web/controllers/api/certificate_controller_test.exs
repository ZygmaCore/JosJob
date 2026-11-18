defmodule JosjobWeb.Api.CertificateControllerTest do
  use JosjobWeb.ConnCase, async: true
  require Ash.Query
  import JosjobWeb.JobFixtures, only: [auth: 2, user!: 0]
  alias Josjob.Accounts.Profile
  alias JosjobLrn.Certificates
  alias JosjobLrn.Certificates.Certificate

  defp attrs,
    do: %{
      "title" => "First aid training",
      "issuer" => "Local training provider",
      "issued_on" => "2025-01-01",
      "expires_on" => "2026-01-01",
      "credential_url" => "https://example.com/credential",
      "credential_id" => "FA-123"
    }

  defp listing(conn, user),
    do:
      conn
      |> auth(user)
      |> get(~p"/api/me/certificates")
      |> json_response(200)
      |> Map.fetch!("data")

  test "all endpoints require authentication", %{conn: conn} do
    id = Ecto.UUID.generate()
    assert conn |> get(~p"/api/me/certificates") |> json_response(401)
    assert conn |> post(~p"/api/me/certificates", attrs()) |> json_response(401)
    assert conn |> patch(~p"/api/me/certificates/#{id}", attrs()) |> json_response(401)
    assert conn |> delete(~p"/api/me/certificates/#{id}") |> json_response(401)
  end

  test "certificate CRUD is persisted, private and never self-verifies", %{conn: conn} do
    user = user!()
    other = user!()
    assert listing(conn, user) == []

    payload =
      Map.merge(attrs(), %{
        "user_id" => other.id,
        "source" => "platform",
        "verified" => true,
        "editable" => false
      })

    certificate =
      conn
      |> auth(user)
      |> post(~p"/api/me/certificates", payload)
      |> json_response(201)
      |> Map.fetch!("data")

    id = certificate["id"]
    assert certificate["source"] == "self_reported"
    assert certificate["editable"]
    assert certificate["expired"] == (Date.compare(~D[2026-01-01], Date.utc_today()) == :lt)
    refute Map.has_key?(certificate, "verified")
    assert Ash.get!(Certificate, id, authorize?: false).user_id == user.id
    assert [%{"id" => ^id}] = listing(conn, user)
    assert listing(conn, other) == []

    assert conn
           |> auth(other)
           |> patch(~p"/api/me/certificates/#{id}", %{"title" => "Stolen"})
           |> json_response(404)

    assert conn |> auth(other) |> delete(~p"/api/me/certificates/#{id}") |> json_response(404)

    edited =
      conn
      |> auth(user)
      |> patch(~p"/api/me/certificates/#{id}", %{
        "title" => "Updated first aid",
        "credential_url" => "",
        "user_id" => other.id
      })
      |> json_response(200)
      |> Map.fetch!("data")

    assert edited["title"] == "Updated first aid"
    assert edited["credential_url"] == nil
    assert edited["issued_on"] == "2025-01-01"

    assert conn |> auth(user) |> delete(~p"/api/me/certificates/#{id}") |> json_response(200) ==
             %{"ok" => true}

    assert listing(conn, user) == []
  end

  test "validates titles, dates and external links and permits missing optional details", %{
    conn: conn
  } do
    user = user!()

    for changes <- [
          %{"title" => "  "},
          %{"issuer" => ""},
          %{"issued_on" => "2025-02-30"},
          %{"issued_on" => "2999-01-01"},
          %{"expires_on" => "2024-01-01"},
          %{"credential_url" => "javascript:alert(1)"},
          %{"credential_url" => "https://user:pass@example.com"},
          %{"credential_url" => "//example.com"},
          %{"credential_url" => %{}}
        ] do
      assert conn
             |> auth(user)
             |> post(~p"/api/me/certificates", Map.merge(attrs(), changes))
             |> json_response(422)
    end

    assert listing(conn, user) == []

    {:ok, c} =
      Certificates.add_certificate(user, %{
        "title" => "  Safety awareness ",
        "issuer" => " Training provider "
      })

    assert c.title == "Safety awareness"
    assert c.issued_on == nil

    assert conn
           |> auth(user)
           |> patch(~p"/api/me/certificates/#{c.id}", %{"expires_on" => "2024-01-01"})
           |> json_response(200)

    assert conn
           |> auth(user)
           |> patch(~p"/api/me/certificates/#{c.id}", %{"issued_on" => "2025-01-01"})
           |> json_response(422)

    assert conn
           |> auth(user)
           |> patch(~p"/api/me/certificates/not-an-id", attrs())
           |> json_response(404)

    assert conn
           |> auth(user)
           |> delete(~p"/api/me/certificates/onboarding-0")
           |> json_response(404)
  end

  test "shows only the caller's actual onboarding certifications without inventing dates or awards",
       %{conn: conn} do
    user = user!()
    other = user!()

    answers = %{
      "achievements" => [
        %{
          "type" => "Certification",
          "name" => "Onboarding safety",
          "issuer" => "Original issuer",
          "from" => %{"year" => 2024, "month" => 3},
          "to" => %{"year" => 2025}
        },
        %{"type" => "Course", "name" => "Only a course"},
        %{"type" => "Certification", "name" => "Missing date", "from" => "broken"},
        %{"type" => "Certification", "name" => "  "},
        nil,
        "invalid"
      ],
      "skills" => ["Safety"]
    }

    Profile
    |> Ash.Changeset.for_create(:upsert_answers, %{user_id: user.id, answers: answers})
    |> Ash.create!(authorize?: false)

    assert [first, second] = listing(conn, user)
    assert first["title"] == "Onboarding safety"
    assert first["recorded_period"] == "2024-03 – 2025"
    assert first["source"] == "onboarding"
    refute first["editable"]
    assert first["issued_on"] == nil
    assert second["recorded_period"] == ""
    assert listing(conn, other) == []
    stored = Profile |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)
    assert stored.answers == answers
  end
end
