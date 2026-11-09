defmodule StellarWeb.Api.DocumentUploadTest do
  @moduledoc "HTTP: upload dokumen non-video (presigned URL + simpan Document)."
  use StellarWeb.ConnCase, async: false

  alias Stellar.Accounts.{Tokens, User}
  alias Stellar.Orgs.{Membership, Organization}

  setup %{conn: conn} do
    user = create_user!("member@example.com")

    org =
      Organization
      |> Ash.Changeset.for_create(:create, %{name: "Org #{uniq()}", user_id: user.id})
      |> Ash.create!(authorize?: false)

    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      organization_id: org.id,
      status: :active
    })
    |> Ash.create!(authorize?: false)

    {:ok, tokens} = Tokens.issue_pair(user)
    %{conn: put_req_header(conn, "accept", "application/json"), token: tokens.token}
  end

  test "POST /api/documents persists a standalone document (course_id null)", %{
    conn: conn,
    token: token
  } do
    conn =
      conn
      |> auth(token)
      |> post(~p"/api/documents", %{
        title: "Syllabus",
        url: "https://cdn.example.com/x.pdf",
        mime_type: "application/pdf"
      })

    assert %{"data" => data} = json_response(conn, 201)
    assert data["title"] == "Syllabus"
    assert is_nil(data["course_id"])
    assert data["mime_type"] == "application/pdf"
  end

  test "POST /api/documents requires title + url", %{conn: conn, token: token} do
    conn = conn |> auth(token) |> post(~p"/api/documents", %{url: "https://x/y.pdf"})
    assert json_response(conn, 422)["error"] == "title_required"
  end

  test "POST /api/documents/upload-url -> 503 when object storage not configured", %{
    conn: conn,
    token: token
  } do
    # Deterministic regardless of ambient env (envs/.env may point S3 at MinIO):
    # force the storage to look unconfigured for this test only.
    prev = Application.get_env(:stellar_ms, StellarMs.S3Storage, [])
    Application.put_env(:stellar_ms, StellarMs.S3Storage, [])
    on_exit(fn -> Application.put_env(:stellar_ms, StellarMs.S3Storage, prev) end)

    conn = conn |> auth(token) |> post(~p"/api/documents/upload-url", %{filename: "notes.pdf"})
    assert json_response(conn, 503)["error"] == "storage_not_configured"
  end

  test "requires auth (401)", %{conn: conn} do
    assert json_response(post(conn, ~p"/api/documents", %{title: "x", url: "y"}), 401)
  end

  defp create_user!(email) do
    User
    |> Ash.Changeset.for_create(:register_with_email, %{
      email: email,
      full_name: "U",
      password: "password123"
    })
    |> Ash.create!(authorize?: false)
  end

  defp auth(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token}")
  defp uniq, do: System.unique_integer([:positive])
end
