defmodule StellarRag.AtomicClientTest do
  use ExUnit.Case, async: true

  alias StellarRag.AtomicClient

  setup context do
    # Register the test stub for this process from ExUnit context
    Req.Test.set_req_test_from_context(context)
    :ok
  end

  test "list_databases/0 returns database list on success" do
    Req.Test.stub(AtomicClient, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/databases"

      Req.Test.json(conn, [%{"id" => "db_1", "name" => "db_1"}])
    end)

    assert {:ok, [%{"id" => "db_1", "name" => "db_1"}]} = AtomicClient.list_databases()
  end

  test "create_database/1 creates a database on success" do
    Req.Test.stub(AtomicClient, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/databases"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"id" => "new_db"} = Jason.decode!(body)

      Req.Test.json(conn, %{"id" => "new_db", "status" => "created"})
    end)

    assert {:ok, %{"id" => "new_db"}} = AtomicClient.create_database("new_db")
  end

  test "list_atoms/1 returns list of documents on success" do
    Req.Test.stub(AtomicClient, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/atoms"
      assert conn.query_string == "db=db_1"

      # Verify DB header
      db_header = Plug.Conn.get_req_header(conn, "x-atomic-database")
      assert db_header == ["db_1"]

      Req.Test.json(conn, [%{"id" => "atom_1", "title" => "doc.pdf"}])
    end)

    assert {:ok, [%{"id" => "atom_1", "title" => "doc.pdf"}]} = AtomicClient.list_atoms("db_1")
  end

  test "create_atom/3 creates document inside database" do
    Req.Test.stub(AtomicClient, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/atoms"
      assert conn.query_string == "db=db_1"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"title" => "doc.pdf", "content" => "extracted text"} = Jason.decode!(body)

      Req.Test.json(conn, %{"id" => "atom_123", "status" => "indexed"})
    end)

    assert {:ok, %{"id" => "atom_123"}} =
             AtomicClient.create_atom("db_1", "doc.pdf", "extracted text")
  end

  test "delete_atom/2 deletes document from database" do
    Req.Test.stub(AtomicClient, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/api/atoms/atom_123"
      assert conn.query_string == "db=db_1"

      Req.Test.json(conn, %{"deleted" => true})
    end)

    assert {:ok, %{"deleted" => true}} = AtomicClient.delete_atom("db_1", "atom_123")
  end
end
