defmodule JosjobMs.RealtimeTest do
  use ExUnit.Case, async: false

  @mod JosjobMs.CloudflareRealtime

  # Kosongkan config secara eksplisit supaya gating test deterministik dan TIDAK
  # bergantung pada envs/.env ambient (di mesin dev bisa sudah terisi kredensial).
  setup do
    prev = Application.get_env(:josjob_ms, @mod, [])
    Application.put_env(:josjob_ms, @mod, [])
    on_exit(fn -> Application.put_env(:josjob_ms, @mod, prev) end)
    :ok
  end

  describe "gating tanpa kredensial" do
    test "configured?/0 false saat env Cloudflare Realtime kosong (dev/test)" do
      refute JosjobMs.Realtime.configured?()
      refute JosjobMs.Realtime.turn_configured?()
    end

    test "fungsi jaringan mengembalikan {:error, :not_configured} saat belum dikonfigurasi" do
      assert {:error, :not_configured} = JosjobMs.Realtime.new_session()
      assert {:error, :not_configured} = JosjobMs.Realtime.ice_servers()
      assert {:error, :not_configured} = JosjobMs.Realtime.publish_tracks("sid", "v=0", [])
      assert {:error, :not_configured} = JosjobMs.Realtime.pull_tracks("sid", [])
      assert {:error, :not_configured} = JosjobMs.Realtime.renegotiate("sid", "v=0")
      assert {:error, :not_configured} = JosjobMs.Realtime.close_tracks("sid", ["0"])
    end
  end
end
