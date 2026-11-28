defmodule JosjobRagpdfWeb.RouterTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias JosjobRagpdf.{Jobs, Queue}

  @token "test-token"
  @fake_pdf "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"

  setup do
    previous_token = Application.get_env(:josjob_ragpdf, :api_token)
    Application.put_env(:josjob_ragpdf, :api_token, @token)

    Queue.reset()
    Jobs.clear()

    on_exit(fn ->
      Application.put_env(:josjob_ragpdf, :api_token, previous_token)
      Queue.reset()
      Jobs.clear()
    end)

    :ok
  end

  describe "GET /health" do
    test "is public and reports queue stats" do
      conn = public_request(:get, "/health")

      assert conn.status == 200
      assert %{"data" => data} = decode(conn)
      assert data["status"] == "ok"
      assert data["service"] == "josjob_ragpdf"
      assert data["queue"]["max_concurrency"] >= 1
      assert is_map(data["jobs"])
    end
  end

  describe "auth" do
    test "rejects /v1 without a token" do
      conn = public_request(:get, "/v1/queue")
      assert conn.status == 401
      assert %{"error" => "unauthorized"} = decode(conn)
    end

    test "accepts a bearer token" do
      conn = request(:get, "/v1/queue")
      assert conn.status == 200
    end

    test "accepts x-api-key" do
      conn =
        :get
        |> conn("/v1/queue")
        |> put_req_header("x-api-key", @token)
        |> JosjobRagpdfWeb.Router.call([])

      assert conn.status == 200
    end
  end

  describe "POST /v1/cv/analyses" do
    test "requires user_id" do
      conn = json_post(%{"content_base64" => Base.encode64(@fake_pdf)})

      assert conn.status == 422
      assert %{"error" => "validation_failed", "fields" => %{"user_id" => _}} = decode(conn)
    end

    test "rejects invalid base64" do
      conn = json_post(%{"user_id" => "u1", "content_base64" => "!!!not-base64!!!"})

      assert conn.status == 400
      assert %{"error" => "invalid_params"} = decode(conn)
    end

    test "rejects non-PDF base64 content" do
      conn = json_post(%{"user_id" => "u1", "content_base64" => Base.encode64("hello world")})

      assert conn.status == 415
    end

    test "rejects non-http file URLs" do
      conn = json_post(%{"user_id" => "u1", "file_url" => "ftp://example.com/cv.pdf"})

      assert conn.status == 422
    end

    test "accepts base64, can be polled, and can be deleted" do
      conn =
        json_post(%{
          "user_id" => "u1",
          "cv_id" => "cv1",
          "filename" => "cv.pdf",
          "content_base64" => Base.encode64(@fake_pdf)
        })

      assert conn.status == 202
      assert %{"data" => data} = decode(conn)
      assert String.starts_with?(data["id"], "job_")
      assert data["status"] in ["queued", "processing", "failed", "unreadable"]
      assert data["cv_id"] == "cv1"

      id = data["id"]

      show = request(:get, "/v1/cv/analyses/#{id}")
      assert show.status == 200
      assert %{"data" => %{"id" => ^id}} = decode(show)

      delete = request(:delete, "/v1/cv/analyses/#{id}")
      assert delete.status == 204

      assert request(:get, "/v1/cv/analyses/#{id}").status == 404
    end

    test "accepts a multipart PDF upload" do
      path = tmp_pdf_path()
      File.write!(path, @fake_pdf)
      on_exit(fn -> File.rm(path) end)

      upload = %Plug.Upload{path: path, filename: "cv.pdf", content_type: "application/pdf"}

      conn =
        :post
        |> conn("/v1/cv/analyses", %{"user_id" => "u1", "file" => upload})
        |> authed()
        |> JosjobRagpdfWeb.Router.call([])

      assert conn.status == 202
      assert %{"data" => %{"id" => id}} = decode(conn)
      assert String.starts_with?(id, "job_")
    end

    test "rejects a non-PDF multipart upload" do
      path = tmp_pdf_path()
      File.write!(path, "plain text")
      on_exit(fn -> File.rm(path) end)

      upload = %Plug.Upload{path: path, filename: "cv.txt", content_type: "text/plain"}

      conn =
        :post
        |> conn("/v1/cv/analyses", %{"user_id" => "u1", "file" => upload})
        |> authed()
        |> JosjobRagpdfWeb.Router.call([])

      assert conn.status == 415
    end

    test "is idempotent per user and key" do
      payload = %{
        "user_id" => "u1",
        "filename" => "cv.pdf",
        "idempotency_key" => "same-key",
        "content_base64" => Base.encode64(@fake_pdf)
      }

      first = json_post(payload)
      assert first.status == 202
      %{"data" => %{"id" => id}} = decode(first)

      second = json_post(payload)
      assert second.status == 200
      assert %{"data" => %{"id" => ^id}} = decode(second)
    end
  end

  describe "unknown routes" do
    test "return JSON 404" do
      conn = request(:get, "/nope")

      assert conn.status == 404
      assert %{"error" => "not_found"} = decode(conn)
    end

    test "DELETE of an unknown analysis returns 404" do
      conn = request(:delete, "/v1/cv/analyses/job_missing")

      assert conn.status == 404
    end
  end

  # --- helpers -----------------------------------------------------------

  defp request(method, path) do
    method
    |> conn(path)
    |> authed()
    |> JosjobRagpdfWeb.Router.call([])
  end

  defp public_request(method, path) do
    method
    |> conn(path)
    |> JosjobRagpdfWeb.Router.call([])
  end

  defp authed(conn) do
    put_req_header(conn, "authorization", "Bearer #{@token}")
  end

  defp json_post(payload) do
    :post
    |> conn("/v1/cv/analyses", Jason.encode!(payload))
    |> put_req_header("content-type", "application/json")
    |> authed()
    |> JosjobRagpdfWeb.Router.call([])
  end

  defp decode(conn), do: Jason.decode!(conn.resp_body)

  defp tmp_pdf_path do
    Path.join(System.tmp_dir!(), "josjob_ragpdf-router-#{System.unique_integer([:positive])}.pdf")
  end
end
