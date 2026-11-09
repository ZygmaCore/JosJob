defmodule StellarMsTest do
  @moduledoc "Media streaming (Cloudflare Stream): normalize, webhook signature, HLS URL, facade."
  use ExUnit.Case, async: false

  alias StellarMs.CloudflareStream

  test "normalize/1 maps a Cloudflare video payload" do
    info =
      CloudflareStream.normalize(%{
        "uid" => "abc",
        "status" => %{"state" => "ready"},
        "readyToStream" => true,
        "duration" => 42.9,
        "playback" => %{"hls" => "https://cf/abc/manifest/video.m3u8"},
        "thumbnail" => "https://cf/abc/thumb.jpg"
      })

    assert info.uid == "abc"
    assert info.state == "ready"
    assert info.ready_to_stream
    assert info.duration_seconds == 42
    assert info.hls_url =~ "video.m3u8"
    assert info.thumbnail_url =~ "thumb"
  end

  test "verify_webhook/2 accepts a valid signature, rejects bad/malformed" do
    prev = Application.get_env(:stellar_ms, CloudflareStream)
    Application.put_env(:stellar_ms, CloudflareStream, webhook_secret: "s3cr3t")
    on_exit(fn -> Application.put_env(:stellar_ms, CloudflareStream, prev || []) end)

    body = ~s({"uid":"abc"})
    time = "1700000000"

    good =
      :crypto.mac(:hmac, :sha256, "s3cr3t", "#{time}.#{body}") |> Base.encode16(case: :lower)

    assert CloudflareStream.verify_webhook(body, "time=#{time},sig1=#{good}")
    refute CloudflareStream.verify_webhook(body, "time=#{time},sig1=deadbeef")
    refute CloudflareStream.verify_webhook(body, "malformed")
  end

  test "hls_url_for/1 is nil without a customer subdomain" do
    prev = Application.get_env(:stellar_ms, CloudflareStream)
    Application.put_env(:stellar_ms, CloudflareStream, [])
    on_exit(fn -> Application.put_env(:stellar_ms, CloudflareStream, prev || []) end)

    assert CloudflareStream.hls_url_for("abc") == nil
    assert CloudflareStream.hls_url_for(nil) == nil
  end

  test "StellarMs facade delegates to the provider client" do
    assert StellarMs.normalize(%{"uid" => "z"}).uid == "z"
    assert is_boolean(StellarMs.configured?())
  end
end
