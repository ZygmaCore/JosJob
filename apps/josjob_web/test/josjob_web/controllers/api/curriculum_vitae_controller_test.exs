defmodule JosjobWeb.Api.CurriculumVitaeControllerTest do
  use JosjobWeb.ConnCase, async: true
  require Ash.Query
  import JosjobWeb.JobFixtures, only: [auth: 2, user!: 0, organization!: 1]
  alias Josjob.Accounts.Profile
  alias JosjobDoc.Documents.Document
  alias JosjobJob.CurriculumVitae

  defp cv(conn, user),
    do: conn |> auth(user) |> get(~p"/api/me/cv") |> json_response(200) |> Map.fetch!("data")

  defp answers!(user, answers),
    do:
      Profile
      |> Ash.Changeset.for_create(:upsert_answers, %{user_id: user.id, answers: answers})
      |> Ash.create!(authorize?: false)

  defp doc!(user, org, attrs \\ %{}),
    do:
      Document
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(
          %{
            title: "My resume",
            url: "https://example.com/resume.pdf",
            mime_type: "application/pdf",
            user_id: user.id,
            organization_id: org.id
          },
          attrs
        )
      )
      |> Ash.create!(authorize?: false)

  test "authentication, real identity and honest empty states", %{conn: conn} do
    assert conn |> get(~p"/api/me/cv") |> json_response(401)
    assert conn |> patch(~p"/api/me/cv", %{"headline" => "Ignored"}) |> json_response(401)
    user = user!()
    data = cv(conn, user)
    assert data["identity"]["full_name"] == user.full_name
    assert data["identity"]["email"] == to_string(user.email)
    assert data["experience"] == []
    assert data["education"] == []
    assert data["skills"] == []
    assert data["certificates"] == []
    assert data["headline"] == nil
    assert data["summary"] == nil
    assert data["resume_document"] == nil
    refute Map.has_key?(data, "profile_strength")
  end

  test "reads only saved facts and exact date precision, and keeps CV edits separate from onboarding",
       %{conn: conn} do
    user = user!()

    answers = %{
      "phone" => "+62 12345",
      "country" => "Indonesia",
      "fullName" => "Forged name",
      "skills" => [" SQL ", "Elixir", "sql", nil],
      "employments" => [
        %{
          "name" => "Actual employer",
          "position" => "Developer",
          "industry" => "Technology",
          "from" => %{"year" => 2021, "month" => 4},
          "to" => nil
        },
        nil,
        %{}
      ],
      "educations" => [
        %{
          "name" => "Actual university",
          "degree" => "Degree",
          "major" => "Computer science",
          "from" => %{"year" => 2017},
          "to" => %{"year" => 2021, "month" => 3}
        }
      ],
      "achievements" => [%{"type" => "Certification", "name" => "Actual certificate"}],
      "unrelated" => ["keep"]
    }

    saved = answers!(user, answers)
    data = cv(conn, user)
    assert data["identity"]["full_name"] == user.full_name
    assert data["identity"]["phone"] == "+62 12345"
    assert data["skills"] == ["SQL", "Elixir"]
    assert [%{"from" => "2021-04", "to" => nil, "position" => "Developer"}] = data["experience"]

    assert [%{"from" => "2017", "to" => "2021-03", "name" => "Actual university"}] =
             data["education"]

    assert [%{"title" => "Actual certificate", "source" => "onboarding"}] = data["certificates"]

    conn
    |> auth(user)
    |> patch(~p"/api/me/cv", %{
      "headline" => " Software developer ",
      "summary" => "My real summary",
      "user_id" => Ecto.UUID.generate(),
      "is_superuser" => true,
      "email" => "forged@example.com",
      "skills" => ["Injected"]
    })
    |> json_response(200)

    assert Ash.get!(Profile, saved.id, authorize?: false).answers == answers
    assert cv(conn, user)["headline"] == "Software developer"
    answers!(user, Map.put(answers, "skills", ["Updated skill"]))
    assert cv(conn, user)["summary"] == "My real summary"
    assert cv(conn, user)["skills"] == ["Injected"]
    assert cv(conn, user!())["headline"] == nil
  end

  test "only explicitly attached owned standalone PDFs are selectable, even for admins", %{
    conn: conn
  } do
    user = user!()
    other = user!()
    org = organization!(user)
    own = doc!(user, org)
    foreign = doc!(other, org)
    course = doc!(user, org, %{course_id: Ecto.UUID.generate()})
    video = doc!(user, org, %{mime_type: "video/mp4"})
    unsafe = doc!(user, org, %{url: "javascript:alert(1)"})
    data = cv(conn, user)
    assert data["resume_document"] == nil
    assert Enum.map(data["pdf_documents"], & &1["id"]) == [own.id]

    for id <- [foreign.id, course.id, video.id, unsafe.id, Ecto.UUID.generate(), "malformed"] do
      assert conn
             |> auth(user)
             |> patch(~p"/api/me/cv", %{"resume_document_id" => id})
             |> json_response(422)
    end

    attached =
      conn
      |> auth(user)
      |> patch(~p"/api/me/cv", %{"resume_document_id" => own.id, "headline" => "My headline"})
      |> json_response(200)

    assert attached["data"]["resume_document"]["id"] == own.id
    assert cv(conn, other)["resume_document"] == nil

    admin =
      other
      |> Ash.Changeset.for_update(:update, %{is_superuser: true})
      |> Ash.update!(authorize?: false)

    assert conn
           |> auth(admin)
           |> patch(~p"/api/me/cv", %{"resume_document_id" => own.id})
           |> json_response(422)

    # Recheck ownership on every read, not only when the pointer was saved.
    own
    |> Ash.Changeset.for_update(:update, %{user_id: other.id})
    |> Ash.update!(authorize?: false)

    assert cv(conn, user)["resume_document"] == nil
  end

  test "partial updates, detaching and deleted document references preserve other CV fields", %{
    conn: conn
  } do
    user = user!()
    own = doc!(user, organization!(user))

    {:ok, _} =
      CurriculumVitae.save_for(user, %{
        "headline" => "Title",
        "summary" => "Summary",
        "resume_document_id" => own.id
      })

    assert conn
           |> auth(user)
           |> patch(~p"/api/me/cv", %{"summary" => "New summary"})
           |> json_response(200)

    assert cv(conn, user)["headline"] == "Title"
    Ash.destroy!(own, authorize?: false)
    data = cv(conn, user)
    assert data["resume_document"] == nil
    assert data["summary"] == "New summary"

    cleared =
      conn
      |> auth(user)
      |> patch(~p"/api/me/cv", %{"summary" => " ", "headline" => nil, "resume_document_id" => nil})
      |> json_response(200)

    assert cleared["data"]["summary"] == nil
    assert cleared["data"]["headline"] == nil
  end

  test "invalid fields and malformed onboarding sections never create fake facts", %{conn: conn} do
    user = user!()

    answers!(user, %{
      "skills" => %{},
      "employments" => "invalid",
      "educations" => [%{}, nil],
      "phone" => %{}
    })

    for attrs <- [
          %{"headline" => String.duplicate("x", 201)},
          %{"summary" => String.duplicate("x", 4001)},
          %{"headline" => %{}}
        ] do
      assert conn |> auth(user) |> patch(~p"/api/me/cv", attrs) |> json_response(422)
    end

    data = cv(conn, user)
    assert data["headline"] == nil
    assert data["identity"]["phone"] == nil
    assert data["experience"] == []
    assert data["education"] == []
    assert data["skills"] == []
  end
end
