defmodule StellarMs.CloudflareStream do
  @moduledoc """
  Klien Cloudflare Stream — platform video terkelola (upload -> transcode ->
  HLS/DASH -> CDN). Menggantikan pipeline transcode self-host.

  Kredensial dibaca dari config env (lihat config/runtime.exs):
    - account_id      : CLOUDFLARE_ACCOUNT_ID
    - api_token       : CLOUDFLARE_STREAM_TOKEN (scope Stream:Edit)
    - webhook_secret  : CLOUDFLARE_STREAM_WEBHOOK_SECRET (untuk verifikasi webhook)

  Bila belum dikonfigurasi, fungsi jaringan mengembalikan {:error, :not_configured}
  sehingga dev/seed tetap jalan tanpa token (upload nyata baru bekerja setelah
  token diisi).
  """

  @api "https://api.cloudflare.com/client/v4"

  @doc "True bila account_id + api_token tersedia."
  def configured? do
    is_binary(account_id()) and account_id() != "" and
      is_binary(api_token()) and api_token() != ""
  end

  @doc """
  Buat URL upload sekali-pakai (direct creator upload). Klien lalu meng-upload
  file langsung ke `upload_url` (POST field `file`, atau tus untuk file besar).

  Opsi: `:max_duration_seconds` (default 3600), `:creator` (id opsional).
  Mengembalikan {:ok, %{uid, upload_url}} | {:error, reason}.
  """
  def create_direct_upload(opts \\ []) do
    with :ok <- ensure_configured() do
      body =
        %{maxDurationSeconds: Keyword.get(opts, :max_duration_seconds, 3600)}
        |> maybe_put(:creator, opts[:creator])

      case Req.post(req(), url: "/accounts/#{account_id()}/stream/direct_upload", json: body) do
        {:ok, %{status: 200, body: %{"result" => %{"uploadURL" => url, "uid" => uid}}}} ->
          {:ok, %{uid: uid, upload_url: url}}

        {:ok, resp} ->
          {:error, {:cloudflare, resp.status, resp.body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Ambil detail/status satu video. Mengembalikan {:ok, info} dengan info yang
  sudah dinormalisasi (lihat `normalize/1`), atau {:error, reason}. 404 -> :not_found.
  """
  def get_video(uid) when is_binary(uid) do
    with :ok <- ensure_configured() do
      case Req.get(req(), url: "/accounts/#{account_id()}/stream/#{uid}") do
        {:ok, %{status: 200, body: %{"result" => result}}} -> {:ok, normalize(result)}
        {:ok, %{status: 404}} -> {:error, :not_found}
        {:ok, resp} -> {:error, {:cloudflare, resp.status, resp.body}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Upload file lokal ke `upload_url` (dari `create_direct_upload/1`) — POST
  multipart field `file`. URL sudah tertandatangani sekali-pakai, jadi TANPA
  header auth. Cocok untuk file kecil (<=200MB, mis. seeder). {:ok} | {:error}.
  """
  def upload_file(upload_url, path) when is_binary(upload_url) and is_binary(path) do
    # Baca ke memori dgn filename + content-type eksplisit: multipart streamed
    # (File.stream!) ditutup koneksinya oleh endpoint upload Cloudflare; bytes
    # in-memory diterima (200). Cocok untuk file kecil (seeder sample).
    part = {File.read!(path), filename: Path.basename(path), content_type: "video/mp4"}

    case Req.post(upload_url,
           form_multipart: [file: part],
           receive_timeout: 120_000,
           retry: :transient,
           max_retries: 3
         ) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, resp} -> {:error, {:upload, resp.status, resp.body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Normalisasi payload video Cloudflare (dari API detail ATAU dari webhook — bentuk
  field-nya sama) ke map internal yang dipakai resource Lecture.
  """
  def normalize(v) when is_map(v) do
    %{
      uid: v["uid"],
      # "pendingupload" | "queued" | "downloading" | "inprogress" | "ready" | "error"
      state: get_in(v, ["status", "state"]),
      ready_to_stream: v["readyToStream"] == true,
      duration_seconds: v["duration"] |> to_number() |> trunc_nonneg(),
      hls_url: get_in(v, ["playback", "hls"]) || hls_url_for(v["uid"]),
      dash_url: get_in(v, ["playback", "dash"]),
      thumbnail_url: v["thumbnail"],
      error_message: get_in(v, ["status", "errorReasonText"])
    }
  end

  @doc """
  Verifikasi tanda tangan webhook Cloudflare Stream. `sig_header` = nilai header
  `Webhook-Signature: time=<unix>,sig1=<hex>`; tanda tangan = HMAC-SHA256 atas
  "<time>.<raw_body>" dengan `webhook_secret`. Perbandingan constant-time.
  """
  def verify_webhook(raw_body, sig_header)
      when is_binary(raw_body) and is_binary(sig_header) do
    secret = webhook_secret()

    with true <- is_binary(secret) and secret != "",
         %{"time" => time, "sig1" => sig} <- parse_sig_header(sig_header) do
      expected =
        :crypto.mac(:hmac, :sha256, secret, "#{time}.#{raw_body}")
        |> Base.encode16(case: :lower)

      Plug.Crypto.secure_compare(expected, sig)
    else
      _ -> false
    end
  end

  @doc """
  Bangun URL playlist HLS dari customer subdomain + uid — fallback bila
  `playback.hls` belum ada di respons. nil bila subdomain tak dikonfigurasi.
  """
  def hls_url_for(uid) when is_binary(uid) and uid != "" do
    case customer_subdomain() do
      sub when is_binary(sub) and sub != "" ->
        "https://#{sub}/#{uid}/manifest/video.m3u8"

      _ ->
        nil
    end
  end

  def hls_url_for(_), do: nil

  # ---- internals -------------------------------------------------------

  defp parse_sig_header(header) do
    header
    |> String.split(",")
    |> Enum.reduce(%{}, fn part, acc ->
      case String.split(part, "=", parts: 2) do
        [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
        _ -> acc
      end
    end)
  end

  # Auth: bila CLOUDFLARE_EMAIL di-set -> Global API Key (X-Auth-Email/Key, untuk
  # testing lokal); selain itu Bearer scoped token (default/produksi).
  defp req do
    auth =
      case auth_email() do
        email when is_binary(email) and email != "" ->
          [headers: [{"X-Auth-Email", email}, {"X-Auth-Key", api_token()}]]

        _ ->
          [auth: {:bearer, api_token()}]
      end

    Req.new([base_url: @api, retry: :transient] ++ auth)
  end

  defp ensure_configured do
    if configured?(), do: :ok, else: {:error, :not_configured}
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, ""), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp to_number(n) when is_number(n), do: n
  defp to_number(_), do: 0
  defp trunc_nonneg(n) when n > 0, do: trunc(n)
  defp trunc_nonneg(_), do: 0

  defp config, do: Application.get_env(:stellar_ms, __MODULE__, [])
  defp account_id, do: config()[:account_id]
  defp api_token, do: config()[:api_token]
  defp auth_email, do: config()[:auth_email]
  defp customer_subdomain, do: config()[:customer_subdomain]
  defp webhook_secret, do: config()[:webhook_secret]
end
