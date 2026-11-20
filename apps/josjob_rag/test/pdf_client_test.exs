defmodule JosjobRag.PdfClientTest do
  use ExUnit.Case, async: true

  alias JosjobRag.PdfClient

  defp fake_http(response, parent \\ self()) do
    fn request ->
      send(parent, {:request, request})
      response
    end
  end

  test "submit/2 posts a JSON extraction request" do
    payload = %{"user_id" => "user-1", "cv_id" => "cv-1"}
    http = fake_http({:ok, %{status: 202, body: %{"data" => %{"id" => "job_1"}}}})

    assert {:ok, %{"data" => %{"id" => "job_1"}}} =
             PdfClient.submit(payload, http_client: http)

    assert_received {:request, request}
    assert request[:method] == :post
    assert request[:url] == "/v1/cv/analyses"
    assert request[:json] == payload
    refute Keyword.has_key?(request, :auth)
  end

  test "get/2 and delete/2 target the analysis path" do
    http = fake_http({:ok, %{status: 200, body: %{"data" => %{"status" => "done"}}}})

    assert {:ok, %{"data" => %{"status" => "done"}}} = PdfClient.get("job_1", http_client: http)
    assert_received {:request, request}
    assert request[:method] == :get
    assert request[:url] == "/v1/cv/analyses/job_1"

    http = fake_http({:ok, %{status: 204, body: ""}})
    assert {:ok, ""} = PdfClient.delete("job_1", http_client: http)
    assert_received {:request, request}
    assert request[:method] == :delete
  end

  test "health/1 skips auth and hits /health" do
    http = fake_http({:ok, %{status: 200, body: %{"status" => "ok"}}})

    assert {:ok, %{"status" => "ok"}} =
             PdfClient.health(http_client: http, api_token: "secret")

    assert_received {:request, request}
    assert request[:url] == "/health"
    refute Keyword.has_key?(request, :auth)
  end

  test "sends a bearer token when one is configured" do
    http = fake_http({:ok, %{status: 200, body: %{}}})

    assert {:ok, %{}} = PdfClient.queue(http_client: http, api_token: "secret")

    assert_received {:request, request}
    assert request[:url] == "/v1/queue"
    assert request[:auth] == {:bearer, "secret"}
  end

  test "maps HTTP and transport errors" do
    http = fake_http({:ok, %{status: 404, body: %{"error" => "not_found"}}})

    assert {:error, {:ragpdf, 404, %{"error" => "not_found"}}} =
             PdfClient.get("missing", http_client: http)

    http = fake_http({:error, :timeout})

    assert {:error, {:ragpdf_transport, :timeout}} =
             PdfClient.get("job_1", http_client: http)
  end

  test "submit_upload/4 sends multipart fields" do
    path =
      Path.join(System.tmp_dir!(), "rag_pdf_client_#{System.unique_integer([:positive])}.pdf")

    File.write!(path, "%PDF-1.4 test")
    on_exit(fn -> File.rm(path) end)

    http = fake_http({:ok, %{status: 202, body: %{"data" => %{"id" => "job_1"}}}})

    upload = %{path: path, filename: "cv.pdf", content_type: "application/pdf"}

    assert {:ok, _body} =
             PdfClient.submit_upload(upload, "user-1", "cv-1",
               http_client: http,
               idempotency_key: "idem-1"
             )

    assert_received {:request, request}

    form = request[:form_multipart]
    assert {:user_id, "user-1"} in form
    assert {:cv_id, "cv-1"} in form
    assert {:filename, "cv.pdf"} in form
    assert {:idempotency_key, "idem-1"} in form

    assert {:file, {file, file_opts}} = List.keyfind(form, :file, 0)
    # The file is sent as a binary, not a stream: Req encodes unknown-length
    # streams as chunked requests, which Bandit (ragpdf) aborts with
    # "Body read timeout".
    assert is_binary(file)
    assert file == "%PDF-1.4 test"
    assert file_opts[:filename] == "cv.pdf"
    assert file_opts[:content_type] == "application/pdf"
  end

  test "submit_upload/4 reports an unreadable file" do
    upload = %{path: "/definitely/missing/cv.pdf", filename: "cv.pdf"}

    assert PdfClient.submit_upload(upload, "user-1", "cv-1") ==
             {:error, {:file_error, :enoent}}
  end

  test "submit_upload/4 rejects a missing file" do
    assert PdfClient.submit_upload(%{}, "user-1", "cv-1") == {:error, :missing_file}
  end

  test "configured?/0 is true with the default local URL" do
    assert PdfClient.configured?()
  end
end
