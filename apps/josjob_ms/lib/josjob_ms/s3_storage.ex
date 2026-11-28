defmodule JosjobMs.S3Storage do
  @moduledoc """
  Object storage S3-compatible (Cloudflare R2 / AWS S3 / MinIO) untuk upload
  dokumen **non-video** (pdf/doc/dll) — pelengkap Cloudflare Stream (video).

  Pola sama dengan `JosjobMs.CloudflareStream`: klien meminta **presigned PUT
  URL**, lalu mengunggah bytes file LANGSUNG ke storage (tanpa lewat backend),
  lalu backend menyimpan `Document` dengan `url` = URL publik objek.

  Presigned URL dibuat lokal (AWS SigV4, query-string auth) TANPA panggilan
  jaringan — cukup HMAC-SHA256 via `:crypto` (jadi app leaf ini tak butuh SDK AWS).

  Kredensial dibaca dari config env (lihat config/runtime.exs):
    - endpoint          : S3_ENDPOINT (mis. https://<acct>.r2.cloudflarestorage.com)
    - region            : S3_REGION (R2 = "auto")
    - bucket            : S3_BUCKET
    - access_key_id     : S3_ACCESS_KEY_ID
    - secret_access_key : S3_SECRET_ACCESS_KEY
    - public_base_url   : S3_PUBLIC_BASE_URL (opsional; base URL baca objek)

  Belum dikonfigurasi → `{:error, :not_configured}` (dev/seed tetap jalan).
  """

  @service "s3"
  @algorithm "AWS4-HMAC-SHA256"
  @unsigned "UNSIGNED-PAYLOAD"
  @default_expires 900

  @doc "True bila endpoint + bucket + kredensial tersedia."
  def configured? do
    c = config()

    present?(c[:endpoint]) and present?(c[:bucket]) and
      present?(c[:access_key_id]) and present?(c[:secret_access_key])
  end

  @doc """
  Buat presigned PUT URL untuk mengunggah satu objek.

  Opsi:
    - `:filename`   — nama file asli (untuk key yang informatif). Default "file".
    - `:expires_in` — masa berlaku URL (detik). Default 900.
    - `:key_prefix` — prefix key. Default "documents".

  Return `{:ok, %{upload_url, key, public_url, method: "PUT"}}` |
  `{:error, :not_configured}`.
  """
  def create_presigned_upload(opts \\ []) do
    if configured?() do
      key = build_key(Keyword.get(opts, :key_prefix, "documents"), Keyword.get(opts, :filename))
      expires = Keyword.get(opts, :expires_in, @default_expires)

      {:ok,
       %{
         upload_url: presign_put(key, expires),
         key: key,
         public_url: public_url_for(key),
         method: "PUT"
       }}
    else
      {:error, :not_configured}
    end
  end

  @doc "URL publik untuk membaca objek `key`."
  def public_url_for(key) do
    c = config()

    case c[:public_base_url] do
      base when is_binary(base) and base != "" ->
        "#{String.trim_trailing(base, "/")}/#{key}"

      _ ->
        "#{String.trim_trailing(c[:endpoint], "/")}/#{c[:bucket]}/#{key}"
    end
  end

  # --- SigV4 presign (query-string) --------------------------------------

  defp presign_put(key, expires) do
    c = config()
    uri = URI.parse(c[:endpoint])
    scheme = uri.scheme || "https"
    host = host_with_port(uri)
    region = c[:region] || "auto"
    {amzdate, datestamp} = timestamps()

    canonical_uri = "/" <> encode_seg(c[:bucket]) <> "/" <> encode_key(key)
    scope = "#{datestamp}/#{region}/#{@service}/aws4_request"

    canonical_query =
      [
        {"X-Amz-Algorithm", @algorithm},
        {"X-Amz-Credential", "#{c[:access_key_id]}/#{scope}"},
        {"X-Amz-Date", amzdate},
        {"X-Amz-Expires", Integer.to_string(expires)},
        {"X-Amz-SignedHeaders", "host"}
      ]
      |> Enum.map(fn {k, v} -> encode(k) <> "=" <> encode(v) end)
      |> Enum.join("&")

    canonical_request =
      Enum.join(
        ["PUT", canonical_uri, canonical_query, "host:#{host}\n", "host", @unsigned],
        "\n"
      )

    string_to_sign =
      Enum.join([@algorithm, amzdate, scope, hex(sha256(canonical_request))], "\n")

    signature = hex(hmac(signing_key(c[:secret_access_key], datestamp, region), string_to_sign))

    "#{scheme}://#{host}#{canonical_uri}?#{canonical_query}&X-Amz-Signature=#{signature}"
  end

  # Sertakan port hanya bila non-default (agar cocok dgn Host header klien).
  defp host_with_port(%URI{host: host, port: port}) when port in [nil, 80, 443], do: host
  defp host_with_port(%URI{host: host, port: port}), do: "#{host}:#{port}"

  defp signing_key(secret, datestamp, region) do
    ("AWS4" <> secret)
    |> hmac(datestamp)
    |> hmac(region)
    |> hmac(@service)
    |> hmac("aws4_request")
  end

  defp timestamps do
    now = DateTime.utc_now()
    {Calendar.strftime(now, "%Y%m%dT%H%M%SZ"), Calendar.strftime(now, "%Y%m%d")}
  end

  # key aman + unik: <prefix>/<rand>/<sanitized-filename>
  defp build_key(prefix, filename) do
    name = (is_binary(filename) && filename) || "file"
    safe = name |> Path.basename() |> String.replace(~r/[^A-Za-z0-9._-]/, "_")
    rand = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    "#{prefix}/#{rand}/#{safe}"
  end

  # RFC3986: encode semua kecuali unreserved (A-Za-z0-9-_.~).
  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  # Path: encode tiap segmen, '/' dipertahankan.
  defp encode_key(key), do: key |> String.split("/") |> Enum.map_join("/", &encode/1)
  defp encode_seg(s), do: encode(s)

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp sha256(data), do: :crypto.hash(:sha256, data)
  defp hex(bin), do: Base.encode16(bin, case: :lower)

  defp present?(v), do: is_binary(v) and v != ""

  defp config, do: Application.get_env(:josjob_ms, __MODULE__, [])
end
