defmodule JosjobMs.CloudflareRealtime do
  @moduledoc """
  Klien Cloudflare Realtime — SFU (fan-out media WebRTC) + TURN (NAT traversal)
  untuk sesi live streaming (kelas, 1-on-1, coaching).

  Dua produk Cloudflare Realtime dipakai, base host sama `rtc.live.cloudflare.com`:
    - SFU  : `/apps/<app_id>/sessions/...`             auth `Bearer <app_secret>`
    - TURN : `/turn/keys/<turn_key_id>/credentials/...` auth `Bearer <turn_token>`

  Kredensial dibaca dari config env (lihat config/runtime.exs):
    - app_id      : CLOUDFLARE_REALTIME_APP_ID
    - app_secret  : CLOUDFLARE_REALTIME_APP_SECRET
    - turn_key_id : CLOUDFLARE_TURN_KEY_ID
    - turn_token  : CLOUDFLARE_TURN_TOKEN

  Bila belum dikonfigurasi, fungsi jaringan mengembalikan `{:error, :not_configured}`
  sehingga dev/seed tetap jalan tanpa kredensial (call nyata bekerja setelah diisi).

  PENTING: `app_secret` TIDAK PERNAH dikirim ke klien — `JosjobWeb.LiveRoomChannel`
  mem-proxy setiap call SFU. Klien hanya menerima ICE server berumur pendek + SDP.
  """

  @sfu "https://rtc.live.cloudflare.com/v1"

  # Call signaling bersifat interaktif & latency-sensitive: batasi retry + timeout
  # agar CF yang lambat/hang tidak memblok proses channel berlama-lama.
  @recv_timeout 10_000
  @max_retries 1

  # TTL kredensial TURN default 24 jam; Cloudflare membatasi maksimum 48 jam.
  @default_ttl 86_400
  @max_ttl 172_800

  @doc "True bila app_id + app_secret tersedia (SFU siap dipakai)."
  def configured? do
    present?(app_id()) and present?(app_secret())
  end

  @doc "True bila turn_key_id + turn_token tersedia (TURN siap dipakai)."
  def turn_configured? do
    present?(turn_key_id()) and present?(turn_token())
  end

  @doc """
  Ambil daftar ICE server (STUN + TURN) berumur pendek dari Cloudflare TURN.

  Opsi:
    - `:ttl` — umur kredensial dalam detik (default #{@default_ttl}, maks #{@max_ttl}).
    - `:keep_port_53` — default `false`; URL port `:53` diblok oleh browser sehingga
      di-drop supaya ICE gathering di klien web tidak time out.

  Mengembalikan `{:ok, [ice_server_map]}` (siap dipakai `RTCConfiguration.iceServers`).
  """
  def ice_servers(opts \\ []) do
    ttl = opts |> Keyword.get(:ttl, @default_ttl) |> min(@max_ttl)

    with :ok <- ensure_turn_configured() do
      case Req.post(req_turn(), url: "/credentials/generate-ice-servers", json: %{ttl: ttl}) do
        {:ok, %{status: status, body: %{"iceServers" => servers}}} when status in 200..299 ->
          {:ok, filter_ice(servers, Keyword.get(opts, :keep_port_53, false))}

        {:ok, resp} ->
          {:error, {:cloudflare, resp.status, resp.body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Buat sesi SFU baru (buka PeerConnection). `{:ok, %{session_id: sid}}` | `{:error}`.

  TANPA body: API menolak body `{}` (400 "Body JSON validation error:
  sessionDescription"); POST tanpa body -> 201 + sessionId (diverifikasi live).
  """
  def new_session do
    with :ok <- ensure_configured(),
         {:ok, body} <- sfu_result(Req.post(req_sfu(), url: "/sessions/new")) do
      {:ok, %{session_id: body["sessionId"]}}
    end
  end

  @doc """
  Publish track lokal: kirim SDP `offer` + daftar track lokal, balas SDP `answer`.
  `tracks` = `[%{"mid" => mid, "trackName" => name}]`. Tidak memicu renegosiasi.
  """
  def publish_tracks(session_id, offer_sdp, tracks)
      when is_binary(session_id) and is_binary(offer_sdp) and is_list(tracks) do
    body = %{
      sessionDescription: %{type: "offer", sdp: offer_sdp},
      tracks:
        Enum.map(tracks, fn t ->
          %{location: "local", mid: t["mid"], trackName: t["trackName"]}
        end)
    }

    with :ok <- ensure_configured(),
         {:ok, resp} <-
           sfu_result(Req.post(req_sfu(), url: "/sessions/#{session_id}/tracks/new", json: body)) do
      {:ok, %{sdp: get_in(resp, ["sessionDescription", "sdp"])}}
    end
  end

  @doc """
  Pull track remote (subscribe) dari satu atau lebih publisher dalam SATU call.
  `remote_tracks` = `[%{"sessionId" => publisher_sid, "trackName" => name}]`.

  SFU menjadi offerer: balasan berisi SDP `offer` + peta `trackName -> mid` +
  `renegotiate` (bool). Bila `renegotiate` true klien wajib setRemoteDescription(offer)
  -> createAnswer -> `renegotiate/2`.
  """
  def pull_tracks(session_id, remote_tracks)
      when is_binary(session_id) and is_list(remote_tracks) do
    body = %{
      tracks:
        Enum.map(remote_tracks, fn t ->
          %{location: "remote", sessionId: t["sessionId"], trackName: t["trackName"]}
        end)
    }

    with :ok <- ensure_configured(),
         {:ok, resp} <-
           sfu_result(Req.post(req_sfu(), url: "/sessions/#{session_id}/tracks/new", json: body)) do
      {:ok,
       %{
         sdp: get_in(resp, ["sessionDescription", "sdp"]),
         tracks: normalize_pull_tracks(resp["tracks"]),
         renegotiate: resp["requiresImmediateRenegotiation"] == true
       }}
    end
  end

  @doc "Kirim SDP `answer` balik ke SFU untuk menuntaskan renegosiasi pull. `:ok` | `{:error}`."
  def renegotiate(session_id, answer_sdp)
      when is_binary(session_id) and is_binary(answer_sdp) do
    body = %{sessionDescription: %{type: "answer", sdp: answer_sdp}}

    with :ok <- ensure_configured(),
         {:ok, _resp} <-
           sfu_result(Req.put(req_sfu(), url: "/sessions/#{session_id}/renegotiate", json: body)) do
      :ok
    end
  end

  @doc """
  Tutup track (berdasarkan `mid`). `force: true` (default) = tutup sisi-server tanpa
  renegosiasi klien. `:ok` | `{:error}`.
  """
  def close_tracks(session_id, mids, force \\ true)
      when is_binary(session_id) and is_list(mids) do
    body = %{tracks: Enum.map(mids, &%{mid: &1}), force: force}

    with :ok <- ensure_configured(),
         {:ok, _resp} <-
           sfu_result(Req.put(req_sfu(), url: "/sessions/#{session_id}/tracks/close", json: body)) do
      :ok
    end
  end

  @doc "Baca status sesi SFU (daftar track + status). `{:ok, body}` | `{:error}`."
  def session_state(session_id) when is_binary(session_id) do
    with :ok <- ensure_configured(),
         {:ok, resp} <- sfu_result(Req.get(req_sfu(), url: "/sessions/#{session_id}")) do
      {:ok, resp}
    end
  end

  # ---- internals -------------------------------------------------------

  # Cloudflare bisa mengembalikan error logis di dalam body 2xx (top-level
  # errorCode/errorDescription) — perlakukan sebagai error.
  defp sfu_result({:ok, %{status: status, body: %{"errorCode" => code} = body}})
       when is_binary(code) and status in 200..299 do
    {:error, {:cloudflare, code, body["errorDescription"]}}
  end

  defp sfu_result({:ok, %{status: status, body: body}}) when status in 200..299, do: {:ok, body}
  defp sfu_result({:ok, resp}), do: {:error, {:cloudflare, resp.status, resp.body}}
  defp sfu_result({:error, reason}), do: {:error, reason}

  defp normalize_pull_tracks(tracks) when is_list(tracks) do
    Enum.map(tracks, fn t ->
      %{track_name: t["trackName"], mid: t["mid"], session_id: t["sessionId"]}
    end)
  end

  defp normalize_pull_tracks(_), do: []

  # Cloudflare TURN bisa mengembalikan `iceServers` sebagai SATU objek
  # (%{"urls"=>..,"username"=>..,"credential"=>..}) ATAU list objek — tangani
  # keduanya, selalu balikkan LIST (siap dipakai RTCConfiguration.iceServers).
  # Buang entri yang jadi tanpa URL setelah difilter.
  defp filter_ice(%{"urls" => urls} = server, keep_53) when is_list(urls) do
    case drop_53(urls, keep_53) do
      [] -> []
      kept -> [Map.put(server, "urls", kept)]
    end
  end

  defp filter_ice(servers, keep_53) when is_list(servers) do
    Enum.flat_map(servers, &filter_ice(&1, keep_53))
  end

  defp filter_ice(_other, _keep_53), do: []

  defp drop_53(urls, true), do: urls

  # Cocokkan port TEPAT (":53" di batas string/query), BUKAN substring — supaya
  # ":5349" (TURNS/TLS) tidak ikut terbuang.
  defp drop_53(urls, false), do: Enum.reject(urls, &String.match?(&1, ~r/:53(\?|$)/))

  defp req_sfu do
    Req.new(
      [
        base_url: "#{@sfu}/apps/#{app_id()}",
        auth: {:bearer, app_secret()},
        retry: :transient,
        max_retries: @max_retries,
        receive_timeout: @recv_timeout
      ] ++ extra_req_opts()
    )
  end

  defp req_turn do
    Req.new(
      [
        base_url: "#{@sfu}/turn/keys/#{turn_key_id()}",
        auth: {:bearer, turn_token()},
        retry: :transient,
        max_retries: @max_retries,
        receive_timeout: @recv_timeout
      ] ++ extra_req_opts()
    )
  end

  # Opsi Req tambahan (mis. `plug: {Req.Test, ...}` untuk test) dari config —
  # kosong di produksi.
  defp extra_req_opts, do: config()[:req_options] || []

  defp ensure_configured, do: if(configured?(), do: :ok, else: {:error, :not_configured})

  defp ensure_turn_configured,
    do: if(turn_configured?(), do: :ok, else: {:error, :not_configured})

  defp present?(v), do: is_binary(v) and v != ""

  defp config, do: Application.get_env(:josjob_ms, __MODULE__, [])
  defp app_id, do: config()[:app_id]
  defp app_secret, do: config()[:app_secret]
  defp turn_key_id, do: config()[:turn_key_id]
  defp turn_token, do: config()[:turn_token]
end
