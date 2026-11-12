defmodule JosjobWeb.LiveRoomChannel do
  @moduledoc """
  Signaling live streaming WebRTC di atas Cloudflare Realtime SFU.

  Topik: `live_room:<room_id>`. Semua peserta terautentikasi (socket JWT). Channel
  ini mem-**proxy** setiap call SFU ke `JosjobMs.Realtime` supaya `app_secret` Cloudflare
  tetap di sisi server — klien tidak pernah bicara langsung ke rtc.live.cloudflare.com.

  Discovery peserta & track memakai `Phoenix.Presence` (lihat `JosjobWeb.Presence`):
  meta tiap peserta membawa `sfu_session_id` + daftar `tracks` yang dipublish, jadi
  subscriber tahu track apa yang harus di-pull. Late joiner & leave ditangani lewat
  `presence_state` (awal) + `presence_diff` (otomatis).

  ## Otorisasi room berbasis kelas (`class:<class_id>[:<mode>]`)
    - Untuk room ber-prefix `class:`, role DITURUNKAN DI SERVER dari domain
      `JosjobLrn.Learning.live_role/2` (instructor → host, student ter-enroll aktif
      → guest) dan payload `role` klien DIABAIKAN. User yang bukan pengajar & tak
      ter-enroll DITOLAK (`unauthorized`) — inilah gerbang enrollment. Ini menutup
      celah spoofing host untuk sesi kelas nyata.

  ## Batas v1 (room bebas / demo, TANPA prefix `class:`)
    - Room bebas masih memakai `role` dari payload klien → perintah host
      (`host:end/mute/remove`) bisa dipalsukan. Dipertahankan untuk kompatibilitas
      demo; alur UI nyata (teacher/student) memakai room `class:` yang tergerbang.
    - Enforcement publish (mis. classroom guest wajib view-only) masih di sisi klien;
      penegakan di server = follow-up.
  """
  use JosjobWeb, :channel

  require Logger

  alias JosjobLrn.Learning

  @modes ~w(classroom one_on_one coaching)
  @roles ~w(host guest)

  @impl true
  def join("live_room:" <> room_id, params, socket) do
    mode = params["mode"] || "coaching"

    cond do
      is_nil(socket.assigns[:current_user]) ->
        {:error, %{reason: "unauthorized"}}

      room_id == "" ->
        {:error, %{reason: "invalid_room"}}

      mode not in @modes ->
        {:error, %{reason: "invalid_mode"}}

      true ->
        case resolve_role(room_id, params, socket) do
          {:ok, role} -> finish_join(room_id, mode, role, params, socket)
          :invalid_role -> {:error, %{reason: "invalid_role"}}
          :forbidden -> {:error, %{reason: "unauthorized"}}
        end
    end
  end

  # Room `class:<id>` → role diturunkan di server (gerbang enrollment); payload
  # `role` diabaikan. Room bebas → role dari payload (divalidasi @roles).
  defp resolve_role(room_id, params, socket) do
    case class_id_from_room(room_id) do
      {:ok, class_id} ->
        case Learning.live_role(class_id, socket.assigns.user_id) do
          nil -> :forbidden
          role -> {:ok, Atom.to_string(role)}
        end

      :error ->
        role = params["role"] || "guest"
        if role in @roles, do: {:ok, role}, else: :invalid_role
    end
  end

  # `class:<uuid>` atau `class:<uuid>:<mode>` → {:ok, uuid}; selain itu :error.
  defp class_id_from_room("class:" <> rest) do
    case rest |> String.split(":", parts: 2) |> List.first() do
      id when is_binary(id) and id != "" -> {:ok, id}
      _ -> :error
    end
  end

  defp class_id_from_room(_), do: :error

  defp finish_join(room_id, mode, role, params, socket) do
    # participant_id (bukan user_id) sebagai kunci presence + prefix trackName —
    # aman untuk user yang membuka lebih dari satu tab/perangkat.
    participant_id = gen_id()

    socket =
      assign(socket, %{
        room_id: room_id,
        mode: mode,
        role: role,
        participant_id: participant_id,
        display_name: params["display_name"] || "Peserta",
        sfu_session_id: nil,
        published_mids: []
      })

    send(self(), :after_join)

    {:ok,
     %{
       configured: JosjobMs.Realtime.configured?(),
       mode: mode,
       self: %{user_id: socket.assigns.user_id, participant_id: participant_id, role: role}
     }, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _ref} =
      JosjobWeb.Presence.track(socket, socket.assigns.participant_id, %{
        user_id: socket.assigns.user_id,
        display_name: socket.assigns.display_name,
        role: socket.assigns.role,
        mode: socket.assigns.mode,
        sfu_session_id: nil,
        tracks: [],
        mic: true,
        cam: true,
        hand: false,
        online_at: System.system_time(:second)
      })

    push(socket, "presence_state", JosjobWeb.Presence.list(socket))
    {:noreply, socket}
  end

  # ---- SFU proxy (semua reply sinkron; sequential per-channel OK) ----------

  @impl true
  def handle_in("ice_servers", _payload, socket) do
    case JosjobMs.Realtime.ice_servers() do
      {:ok, servers} -> {:reply, {:ok, %{ice_servers: servers}}, socket}
      {:error, reason} -> {:reply, reply_error(reason), socket}
    end
  end

  def handle_in("sfu:session", _payload, socket) do
    case JosjobMs.Realtime.new_session() do
      {:ok, %{session_id: sid}} ->
        {:reply, {:ok, %{session_id: sid}}, assign(socket, :sfu_session_id, sid)}

      {:error, reason} ->
        {:reply, reply_error(reason), socket}
    end
  end

  def handle_in("sfu:publish", %{"sdp" => offer, "tracks" => tracks}, socket)
      when is_binary(offer) and is_list(tracks) do
    with_session(socket, fn sid ->
      case JosjobMs.Realtime.publish_tracks(sid, offer, tracks) do
        {:ok, %{sdp: answer}} ->
          mids = tracks |> Enum.map(& &1["mid"]) |> Enum.filter(&is_binary/1)

          socket =
            assign(socket, :published_mids, Enum.uniq(socket.assigns.published_mids ++ mids))

          update_published(socket, sid, tracks)
          {{:ok, %{sdp: answer}}, socket}

        {:error, reason} ->
          {reply_error(reason), socket}
      end
    end)
  end

  def handle_in("sfu:pull", %{"tracks" => remote}, socket) when is_list(remote) do
    with_session(socket, fn sid ->
      case JosjobMs.Realtime.pull_tracks(sid, remote) do
        {:ok, result} -> {{:ok, result}, socket}
        {:error, reason} -> {reply_error(reason), socket}
      end
    end)
  end

  def handle_in("sfu:renegotiate", %{"sdp" => answer}, socket) when is_binary(answer) do
    with_session(socket, fn sid ->
      case JosjobMs.Realtime.renegotiate(sid, answer) do
        :ok -> {{:ok, %{}}, socket}
        {:error, reason} -> {reply_error(reason), socket}
      end
    end)
  end

  def handle_in("sfu:close", payload, socket) when is_map(payload) do
    sid = socket.assigns.sfu_session_id
    mids = payload |> Map.get("mids", []) |> List.wrap()
    names = payload |> Map.get("names", []) |> List.wrap()

    if is_binary(sid) and mids != [] do
      # best-effort — abaikan hasil (track mungkin sudah tertutup di sisi PC).
      JosjobMs.Realtime.close_tracks(sid, mids)
      socket = assign(socket, :published_mids, socket.assigns.published_mids -- mids)
      if names != [], do: remove_published(socket, names)
      {:reply, {:ok, %{}}, socket}
    else
      {:reply, {:ok, %{}}, socket}
    end
  end

  # ---- state peserta (mic/cam/raise-hand) ----------------------------------

  def handle_in("state:update", payload, socket) when is_map(payload) do
    changes = state_changes(payload)

    if changes != %{} do
      JosjobWeb.Presence.update(socket, socket.assigns.participant_id, fn meta ->
        Map.merge(meta, changes)
      end)
    end

    {:reply, {:ok, %{}}, socket}
  end

  # ---- perintah host (v1: dapat dipalsukan — lihat @moduledoc) --------------

  def handle_in("host:end", _payload, socket) do
    host_only(socket, fn ->
      broadcast!(socket, "room_ended", %{by: socket.assigns.user_id})
      {:ok, %{}}
    end)
  end

  def handle_in("host:mute", %{"participant_id" => target}, socket) do
    host_only(socket, fn ->
      broadcast!(socket, "host_mute", %{participant_id: target, by: socket.assigns.user_id})
      {:ok, %{}}
    end)
  end

  def handle_in("host:remove", %{"participant_id" => target}, socket) do
    host_only(socket, fn ->
      broadcast!(socket, "host_remove", %{participant_id: target, by: socket.assigns.user_id})
      {:ok, %{}}
    end)
  end

  # Event tak dikenal / payload bentuk salah dari klien (tak tepercaya) tidak
  # boleh meng-crash proses channel — balas error alih-alih meledak.
  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: "bad_request"}}, socket}
  end

  # Cleanup best-effort: tutup track yang dipublish saat channel berakhir (leave/
  # disconnect/crash). Non-blocking (Task terpisah). Cloudflare akhirnya meng-GC
  # sesi dari PeerConnection yang mati; tidak ada endpoint hapus-sesi eksplisit.
  @impl true
  def terminate(_reason, socket) do
    sid = socket.assigns[:sfu_session_id]
    mids = socket.assigns[:published_mids] || []

    if is_binary(sid) and mids != [] do
      Task.start(fn -> JosjobMs.Realtime.close_tracks(sid, mids, true) end)
    end

    :ok
  end

  # ---- internals -----------------------------------------------------------

  # Jalankan `fun.(sfu_session_id)` bila sesi sudah dibuat; fun mengembalikan
  # `{reply, socket}`. Bila belum -> balas error no_session.
  defp with_session(socket, fun) do
    case socket.assigns.sfu_session_id do
      sid when is_binary(sid) ->
        {reply, socket} = fun.(sid)
        {:reply, reply, socket}

      _ ->
        {:reply, {:error, %{reason: "no_session"}}, socket}
    end
  end

  defp host_only(socket, fun) do
    if socket.assigns.role == "host" do
      {:reply, fun.(), socket}
    else
      {:reply, {:error, %{reason: "forbidden"}}, socket}
    end
  end

  defp update_published(socket, sid, tracks) do
    JosjobWeb.Presence.update(socket, socket.assigns.participant_id, fn meta ->
      %{meta | sfu_session_id: sid, tracks: merge_tracks(meta.tracks, tracks)}
    end)
  end

  defp remove_published(socket, names) do
    JosjobWeb.Presence.update(socket, socket.assigns.participant_id, fn meta ->
      %{meta | tracks: Enum.reject(meta.tracks, &(&1.name in names))}
    end)
  end

  defp merge_tracks(existing, incoming) do
    incoming
    |> Enum.map(&%{name: &1["trackName"], kind: &1["kind"] || "video"})
    |> Enum.concat(existing)
    |> Enum.uniq_by(& &1.name)
  end

  defp state_changes(payload) do
    Enum.reduce(payload, %{}, fn
      {"mic", v}, acc -> Map.put(acc, :mic, v == true)
      {"cam", v}, acc -> Map.put(acc, :cam, v == true)
      {"hand", v}, acc -> Map.put(acc, :hand, v == true)
      _, acc -> acc
    end)
  end

  defp reply_error(:not_configured), do: {:error, %{reason: "not_configured"}}

  defp reply_error({:cloudflare, code, _desc} = err) do
    Logger.warning("LiveRoom SFU error: #{inspect(err)}")
    {:error, %{reason: "cloudflare_error", code: to_string(code)}}
  end

  defp reply_error(other) do
    Logger.warning("LiveRoom error: #{inspect(other)}")
    {:error, %{reason: "error"}}
  end

  defp gen_id, do: 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
