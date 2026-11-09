defmodule StellarMs.CloudflareRealtimeTest do
  # async: false — stub Req.Test + Application.put_env dibaca per-proses.
  use ExUnit.Case, async: false

  alias StellarMs.CloudflareRealtime, as: CF

  @mod StellarMs.CloudflareRealtime

  setup do
    prev = Application.get_env(:stellar_ms, @mod, [])

    Application.put_env(:stellar_ms, @mod,
      app_id: "app-123",
      app_secret: "sfu-secret",
      turn_key_id: "turn-key-9",
      turn_token: "turn-token",
      req_options: [plug: {Req.Test, @mod}]
    )

    on_exit(fn -> Application.put_env(:stellar_ms, @mod, prev) end)
    :ok
  end

  test "configured?/turn_configured? true saat kredensial terisi" do
    assert CF.configured?()
    assert CF.turn_configured?()
  end

  test "new_session POST /apps/<id>/sessions/new tanpa body (API tolak body {})" do
    Req.Test.stub(@mod, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/apps/app-123/sessions/new"
      assert ["Bearer sfu-secret"] = Plug.Conn.get_req_header(conn, "authorization")
      # Regresi: JANGAN kirim body (Cloudflare menolak `{}` dengan 400).
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == ""
      Req.Test.json(conn, %{"sessionId" => "sess-abc"})
    end)

    assert {:ok, %{session_id: "sess-abc"}} = CF.new_session()
  end

  test "publish_tracks kirim offer + tracks lokal, balas answer sdp" do
    Req.Test.stub(@mod, fn conn ->
      assert conn.request_path == "/v1/apps/app-123/sessions/sess-1/tracks/new"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["sessionDescription"] == %{"type" => "offer", "sdp" => "v=0-offer"}
      assert [%{"location" => "local", "mid" => "0", "trackName" => "p1:cam"}] = decoded["tracks"]
      Req.Test.json(conn, %{"sessionDescription" => %{"type" => "answer", "sdp" => "v=0-answer"}})
    end)

    tracks = [%{"mid" => "0", "trackName" => "p1:cam"}]
    assert {:ok, %{sdp: "v=0-answer"}} = CF.publish_tracks("sess-1", "v=0-offer", tracks)
  end

  test "pull_tracks kirim tracks remote, balas offer + peta mid + renegotiate" do
    Req.Test.stub(@mod, fn conn ->
      assert conn.request_path == "/v1/apps/app-123/sessions/sess-1/tracks/new"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert [%{"location" => "remote", "sessionId" => "sess-2", "trackName" => "p2:cam"}] =
               decoded["tracks"]

      Req.Test.json(conn, %{
        "requiresImmediateRenegotiation" => true,
        "sessionDescription" => %{"type" => "offer", "sdp" => "v=0-sfu-offer"},
        "tracks" => [%{"trackName" => "p2:cam", "mid" => "2", "sessionId" => "sess-2"}]
      })
    end)

    remote = [%{"sessionId" => "sess-2", "trackName" => "p2:cam"}]

    assert {:ok, %{sdp: "v=0-sfu-offer", renegotiate: true, tracks: tracks}} =
             CF.pull_tracks("sess-1", remote)

    assert [%{track_name: "p2:cam", mid: "2", session_id: "sess-2"}] = tracks
  end

  test "renegotiate PUT /renegotiate dengan answer" do
    Req.Test.stub(@mod, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v1/apps/app-123/sessions/sess-1/renegotiate"
      Req.Test.json(conn, %{})
    end)

    assert :ok = CF.renegotiate("sess-1", "v=0-answer")
  end

  test "ice_servers (bentuk array) buang HANYA port :53, pertahankan :5349/:443" do
    Req.Test.stub(@mod, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/turn/keys/turn-key-9/credentials/generate-ice-servers"
      assert ["Bearer turn-token"] = Plug.Conn.get_req_header(conn, "authorization")

      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(%{
        "iceServers" => [
          %{"urls" => ["stun:stun.cloudflare.com:3478", "stun:stun.cloudflare.com:53"]},
          %{
            "urls" => [
              "turn:turn.cloudflare.com:53?transport=udp",
              "turns:turn.cloudflare.com:5349?transport=tcp",
              "turns:turn.cloudflare.com:443?transport=tcp"
            ],
            "username" => "u",
            "credential" => "c"
          }
        ]
      })
    end)

    assert {:ok, servers} = CF.ice_servers()
    urls = Enum.flat_map(servers, & &1["urls"])
    refute "stun:stun.cloudflare.com:53" in urls
    refute "turn:turn.cloudflare.com:53?transport=udp" in urls
    # :5349 (TURNS/TLS) tidak boleh ikut terbuang oleh filter :53.
    assert "turns:turn.cloudflare.com:5349?transport=tcp" in urls
    assert "turns:turn.cloudflare.com:443?transport=tcp" in urls
    assert "stun:stun.cloudflare.com:3478" in urls
  end

  test "ice_servers (bentuk objek tunggal) dinormalisasi jadi list + filter :53" do
    Req.Test.stub(@mod, fn conn ->
      Req.Test.json(conn, %{
        "iceServers" => %{
          "urls" => [
            "turn:turn.cloudflare.com:3478?transport=udp",
            "turn:turn.cloudflare.com:53?transport=udp",
            "turns:turn.cloudflare.com:5349?transport=tcp"
          ],
          "username" => "u",
          "credential" => "c"
        }
      })
    end)

    assert {:ok, [server]} = CF.ice_servers()
    assert server["username"] == "u"
    refute "turn:turn.cloudflare.com:53?transport=udp" in server["urls"]
    assert "turns:turn.cloudflare.com:5349?transport=tcp" in server["urls"]
  end

  test "keep_port_53: true mempertahankan URL port :53" do
    Req.Test.stub(@mod, fn conn ->
      Req.Test.json(conn, %{
        "iceServers" => [%{"urls" => ["stun:stun.cloudflare.com:53"]}]
      })
    end)

    assert {:ok, servers} = CF.ice_servers(keep_port_53: true)
    assert servers |> Enum.flat_map(& &1["urls"]) |> Enum.any?(&String.contains?(&1, ":53"))
  end

  test "error Cloudflare (errorCode di body 2xx) dipetakan ke {:error, {:cloudflare, ...}}" do
    Req.Test.stub(@mod, fn conn ->
      Req.Test.json(conn, %{"errorCode" => "sad", "errorDescription" => "boom"})
    end)

    assert {:error, {:cloudflare, "sad", "boom"}} = CF.new_session()
  end
end
