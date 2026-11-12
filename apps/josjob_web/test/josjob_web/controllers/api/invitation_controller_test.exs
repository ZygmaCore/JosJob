defmodule JosjobWeb.Api.InvitationControllerTest do
  @moduledoc "HTTP end-to-end: undangan teacher (admin superuser) + accept publik."
  use JosjobWeb.ConnCase, async: false

  require Ash.Query

  alias Josjob.Accounts.{Tokens, User}
  alias Josjob.Invitations.Invitation
  alias Josjob.Orgs.Organization

  setup %{conn: conn} do
    su = create_user!("super@example.com", superuser: true)
    plain = create_user!("plain@example.com")

    org =
      Organization
      |> Ash.Changeset.for_create(:create, %{name: "Org #{uniq()}", user_id: su.id})
      |> Ash.create!(authorize?: false)

    {:ok, su_tokens} = Tokens.issue_pair(su)
    {:ok, plain_tokens} = Tokens.issue_pair(plain)

    conn = put_req_header(conn, "accept", "application/json")
    %{conn: conn, org: org, su_token: su_tokens.token, plain_token: plain_tokens.token}
  end

  describe "admin teacher-invitations" do
    test "superuser creates a pending invitation", %{conn: conn, org: org, su_token: token} do
      conn =
        conn
        |> auth(token)
        |> post(~p"/api/admin/teacher-invitations", %{
          email: "teach@example.com",
          organization_id: org.id
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["email"] == "teach@example.com"
      assert data["status"] == "pending"
      assert data["organization_id"] == org.id
      assert data["role_key"] == "teacher"
    end

    test "non-superuser is forbidden (403)", %{conn: conn, org: org, plain_token: token} do
      conn =
        conn
        |> auth(token)
        |> post(~p"/api/admin/teacher-invitations", %{
          email: "teach@example.com",
          organization_id: org.id
        })

      assert json_response(conn, 403)
    end

    test "without a token -> 401", %{conn: conn, org: org} do
      conn =
        post(conn, ~p"/api/admin/teacher-invitations", %{
          email: "teach@example.com",
          organization_id: org.id
        })

      assert json_response(conn, 401)
    end

    test "index lists created invitations", %{conn: conn, org: org, su_token: token} do
      conn
      |> auth(token)
      |> post(~p"/api/admin/teacher-invitations", %{
        email: "a@example.com",
        organization_id: org.id
      })

      list_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> auth(token)
        |> get(~p"/api/admin/teacher-invitations")

      assert %{"data" => list} = json_response(list_conn, 200)
      assert Enum.any?(list, &(&1["email"] == "a@example.com"))
    end

    test "organizations dropdown lists orgs for superuser", %{
      conn: conn,
      org: org,
      su_token: token
    } do
      conn = conn |> auth(token) |> get(~p"/api/admin/organizations")
      assert %{"data" => orgs} = json_response(conn, 200)
      assert Enum.any?(orgs, &(&1["id"] == org.id))
    end
  end

  describe "public invitation accept" do
    test "show returns email + org; accept creates a teacher and logs in", %{
      conn: conn,
      org: org,
      su_token: token
    } do
      created =
        conn
        |> auth(token)
        |> post(~p"/api/admin/teacher-invitations", %{
          email: "newteach@example.com",
          organization_id: org.id
        })

      assert json_response(created, 201)

      invite =
        Invitation
        |> Ash.Query.filter(email == "newteach@example.com")
        |> Ash.read_one!(authorize?: false)

      show =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/invitations/#{invite.token}")

      assert json_response(show, 200)["data"]["email"] == "newteach@example.com"
      assert json_response(show, 200)["data"]["organization_name"] == org.name

      accept =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/invitations/#{invite.token}/accept", %{
          full_name: "New Teacher",
          password: "password123"
        })

      body = json_response(accept, 201)
      assert body["is_new_user"] == true
      assert is_binary(body["token"]) and is_binary(body["refresh_token"])
      assert "teacher" in body["user"]["roles"]
      assert body["user"]["mandatory_completed"] == true
    end

    test "unknown token -> 404", %{conn: conn} do
      assert json_response(get(conn, ~p"/api/invitations/does-not-exist"), 404)
    end

    test "accept with short password -> 422", %{conn: conn, org: org, su_token: token} do
      conn
      |> auth(token)
      |> post(~p"/api/admin/teacher-invitations", %{
        email: "short@example.com",
        organization_id: org.id
      })

      invite =
        Invitation
        |> Ash.Query.filter(email == "short@example.com")
        |> Ash.read_one!(authorize?: false)

      resp =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/invitations/#{invite.token}/accept", %{full_name: "X", password: "short"})

      assert json_response(resp, 422)
    end
  end

  defp create_user!(email, opts \\ []) do
    user =
      User
      |> Ash.Changeset.for_create(:register_with_email, %{
        email: email,
        full_name: "User",
        password: "password123"
      })
      |> Ash.create!(authorize?: false)

    if opts[:superuser] do
      user
      |> Ash.Changeset.for_update(:update, %{is_superuser: true})
      |> Ash.update!(authorize?: false)
    else
      user
    end
  end

  defp auth(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token}")
  defp uniq, do: System.unique_integer([:positive])
end
