defmodule JosjobWeb.LiveRoomChannelTest do
  # async: false — memaksa config :josjob_ms (global) supaya deterministik.
  use JosjobWeb.ChannelCase, async: false

  # User palsu — channel hanya membaca current_user (nil-check) + user_id; tanpa DB.
  @user %{id: "user-1"}

  # Paksa Realtime "belum dikonfigurasi" supaya test tidak bergantung pada
  # envs/.env ambient (mesin dev bisa punya kredensial Cloudflare nyata).
  setup do
    prev = Application.get_env(:josjob_ms, JosjobMs.CloudflareRealtime, [])
    Application.put_env(:josjob_ms, JosjobMs.CloudflareRealtime, [])
    on_exit(fn -> Application.put_env(:josjob_ms, JosjobMs.CloudflareRealtime, prev) end)
    :ok
  end

  defp new_socket(assigns \\ %{current_user: @user, user_id: "user-1", is_superuser: false}) do
    socket(JosjobWeb.UserSocket, "users_socket:user-1", assigns)
  end

  defp join(params \\ %{}) do
    params =
      Map.merge(%{"mode" => "coaching", "role" => "guest", "display_name" => "Alice"}, params)

    subscribe_and_join(new_socket(), JosjobWeb.LiveRoomChannel, "live_room:room-1", params)
  end

  describe "join/3" do
    test "sukses: balas configured + mode + self dengan participant_id" do
      assert {:ok, reply, _socket} = join()
      assert reply.mode == "coaching"
      assert reply.configured == false
      assert reply.self.user_id == "user-1"
      assert is_binary(reply.self.participant_id)
      assert reply.self.role == "guest"
    end

    test "push presence_state berisi peserta yang baru track" do
      {:ok, _reply, _socket} = join()
      assert_push "presence_state", state
      assert map_size(state) == 1
    end

    test "tolak user tanpa autentikasi" do
      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(
                 new_socket(%{user_id: "user-1"}),
                 JosjobWeb.LiveRoomChannel,
                 "live_room:room-1",
                 %{"mode" => "coaching", "role" => "guest"}
               )
    end

    test "tolak mode invalid" do
      assert {:error, %{reason: "invalid_mode"}} = join(%{"mode" => "webinar"})
    end

    test "tolak role invalid" do
      assert {:error, %{reason: "invalid_role"}} = join(%{"role" => "admin"})
    end

    test "classroom viewer (mode classroom + role guest) diterima" do
      assert {:ok, reply, _socket} =
               join(%{"mode" => "classroom", "role" => "guest"})

      assert reply.mode == "classroom"
      assert reply.self.role == "guest"
    end
  end

  describe "SFU proxy gating (belum dikonfigurasi)" do
    test "sfu:session -> not_configured" do
      {:ok, _reply, socket} = join()
      ref = push(socket, "sfu:session", %{})
      assert_reply ref, :error, %{reason: "not_configured"}
    end

    test "ice_servers -> not_configured" do
      {:ok, _reply, socket} = join()
      ref = push(socket, "ice_servers", %{})
      assert_reply ref, :error, %{reason: "not_configured"}
    end

    test "sfu:publish tanpa sesi -> no_session" do
      {:ok, _reply, socket} = join()
      ref = push(socket, "sfu:publish", %{"sdp" => "v=0", "tracks" => []})
      assert_reply ref, :error, %{reason: "no_session"}
    end

    test "event tak dikenal dibalas error (catch-all), tidak crash channel" do
      {:ok, _reply, socket} = join()
      ref = push(socket, "bogus:event", %{})
      assert_reply ref, :error, %{reason: "bad_request"}
    end
  end

  describe "state:update" do
    test "memicu presence_diff" do
      {:ok, _reply, socket} = join()
      assert_push "presence_state", _state
      ref = push(socket, "state:update", %{"mic" => false, "hand" => true})
      assert_reply ref, :ok, %{}
      assert_broadcast "presence_diff", _diff
    end
  end

  describe "perintah host (v1: role dari payload)" do
    test "guest ditolak" do
      {:ok, _reply, socket} = join(%{"role" => "guest"})
      ref = push(socket, "host:end", %{})
      assert_reply ref, :error, %{reason: "forbidden"}
    end

    test "host boleh end -> broadcast room_ended" do
      {:ok, _reply, socket} = join(%{"role" => "host"})
      ref = push(socket, "host:end", %{})
      assert_reply ref, :ok, %{}
      assert_broadcast "room_ended", %{by: "user-1"}
    end
  end
end
