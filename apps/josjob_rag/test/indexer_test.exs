defmodule JosjobRag.IndexerTest do
  use Josjob.DataCase, async: false

  alias JosjobRag.Indexer
  alias JosjobRag.AtomicClient

  setup context do
    Req.Test.set_req_test_from_context(context)

    # Create temporary text file for extraction
    tmp_path = Path.join(System.tmp_dir!(), "indexer_test_doc.txt")
    File.write!(tmp_path, "Text to be ingested by the indexer")

    on_exit(fn ->
      File.rm(tmp_path)
    end)

    # Create user for Organization owner
    {:ok, user} =
      Josjob.Accounts.User
      |> Ash.Changeset.for_create(:register_with_email, %{
        email: "indexer_test_#{:crypto.strong_rand_bytes(4) |> Base.encode16()}@example.com",
        full_name: "Indexer Test User",
        password: "password123",
        account_type: "personal"
      })
      |> Ash.create(authorize?: false)

    # Insert a dummy organization to test lookup
    {:ok, org} =
      Josjob.Orgs.Organization
      |> Ash.Changeset.for_create(:create, %{name: "Josjob Test Org", user_id: user.id})
      |> Ash.create(authorize?: false)

    {:ok, tmp_path: tmp_path, org: org, user: user}
  end

  test "get_user_organization_id/1 returns organization ID if it exists", %{org: org} do
    # Fallback lookup returns the first organization in the DB if no membership exists
    assert Indexer.get_user_organization_id("some-user-id") == org.id
  end

  test "ingest/4 successfully orchestrates extraction and atomic upload", %{
    tmp_path: tmp_path,
    org: org
  } do
    db_id = "db_#{org.id}_course_123"

    # Stub the database creation check and the document upload API calls
    Req.Test.stub(AtomicClient, fn conn ->
      case conn.request_path do
        "/api/databases" ->
          if conn.method == "GET" do
            # Simulate database not existing
            Req.Test.json(conn, [])
          else
            # POST - create database
            Req.Test.json(conn, %{"id" => db_id})
          end

        "/api/atoms" ->
          assert conn.method == "POST"
          Req.Test.json(conn, %{"id" => "atom_id_123"})
      end
    end)

    assert {:ok, %{"id" => "atom_id_123"}} =
             Indexer.ingest(tmp_path, "test.txt", "course_123", "user_123")
  end

  test "ingest/4 returns error if extraction fails", %{org: _org} do
    assert {:error, _reason} =
             Indexer.ingest("non_existent_file.pdf", "test.pdf", "course_123", "user_123")
  end
end
