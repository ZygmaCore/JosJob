defmodule StellarMs.S3StorageTest do
  @moduledoc "Presigned PUT URL (AWS SigV4) untuk object storage S3-compatible."
  use ExUnit.Case, async: false

  alias StellarMs.S3Storage

  setup do
    prev = Application.get_env(:stellar_ms, S3Storage, [])

    Application.put_env(:stellar_ms, S3Storage,
      endpoint: "https://acct.r2.cloudflarestorage.com",
      region: "auto",
      bucket: "docs",
      access_key_id: "AKIAEXAMPLE",
      secret_access_key: "secretexample",
      public_base_url: "https://cdn.example.com"
    )

    on_exit(fn -> Application.put_env(:stellar_ms, S3Storage, prev) end)
    :ok
  end

  test "configured? true when credentials present" do
    assert S3Storage.configured?()
  end

  test "create_presigned_upload returns a well-formed SigV4 PUT URL" do
    assert {:ok, up} =
             S3Storage.create_presigned_upload(filename: "my notes.pdf", expires_in: 600)

    assert up.method == "PUT"
    assert String.starts_with?(up.upload_url, "https://acct.r2.cloudflarestorage.com/docs/")
    assert up.upload_url =~ "X-Amz-Algorithm=AWS4-HMAC-SHA256"
    assert up.upload_url =~ "X-Amz-Credential=AKIAEXAMPLE"
    assert up.upload_url =~ "X-Amz-Expires=600"
    assert up.upload_url =~ "X-Amz-SignedHeaders=host"
    assert up.upload_url =~ "X-Amz-Signature="
    # filename disanitasi (spasi → _) dan jadi segmen terakhir key
    assert String.ends_with?(up.key, "my_notes.pdf")
    assert up.public_url == "https://cdn.example.com/#{up.key}"
  end

  test "public_url_for falls back to endpoint/bucket when no public_base_url" do
    Application.put_env(
      :stellar_ms,
      S3Storage,
      Application.get_env(:stellar_ms, S3Storage) |> Keyword.delete(:public_base_url)
    )

    assert S3Storage.public_url_for("documents/abc/x.pdf") ==
             "https://acct.r2.cloudflarestorage.com/docs/documents/abc/x.pdf"
  end

  test "not_configured when credentials missing" do
    Application.put_env(:stellar_ms, S3Storage, [])
    refute S3Storage.configured?()
    assert {:error, :not_configured} = S3Storage.create_presigned_upload(filename: "x.pdf")
  end
end
