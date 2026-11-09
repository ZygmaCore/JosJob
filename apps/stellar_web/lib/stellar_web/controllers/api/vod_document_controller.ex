defmodule StellarWeb.Api.VodDocumentController do
  @moduledoc """
  VOD sebagai **dokumen** (bukan lecture). Klien mobile (Flutter) meng-upload
  video lewat Cloudflare Stream (via facade `StellarMs`) lalu menyimpannya sebagai
  `StellarDoc.Documents.Document` dengan `mime_type` video dan `url` = HLS —
  `course_id` null (dokumen lepas milik user, "dipakai nanti").

  Alur (Bearer access token):

    1. `POST /api/vod/documents/upload-url` → mint one-time Cloudflare upload URL
       (`%{uid, upload_url}`). Klien meng-upload bytes langsung ke `upload_url`.
       Kelayakan (punya org) DICEK DI SINI, sebelum bytes di-upload, agar upload
       tak terbuang + tak meninggalkan aset Cloudflare yatim.
    2. `POST /api/vod/documents` (`%{uid, title, mime_type?, description?}`) →
       buat `Document` (url = `StellarMs.hls_url_for(uid)`).
    3. `GET /api/vod/documents/:uid/status` → status transcode live dari Cloudflare
       (poll sampai `ready`). Di-scope: hanya uid milik dokumen si pemanggil.
  """
  use StellarWeb, :controller

  require Ash.Query
  alias Stellar.Authz
  alias StellarDoc.Documents.Document
  alias StellarWeb.Api.StudentScope

  # Fallback bila customer subdomain belum dikonfigurasi (hls_url_for -> nil).
  # `url` di Document wajib; domain legacy Cloudflare Stream ini tetap melayani HLS.
  defp fallback_hls(uid), do: "https://videodelivery.net/#{uid}/manifest/video.m3u8"

  # POST /api/vod/documents/upload-url
  def create_upload(conn, _params) do
    with {:ok, _org_id} <- resolve_org(conn.assigns.current_user),
         {:ok, %{uid: uid, upload_url: upload_url}} <- StellarMs.create_direct_upload() do
      json(conn, %{data: %{uid: uid, upload_url: upload_url}})
    else
      {:error, :no_organization} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "no_organization"})

      {:error, :not_configured} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "video_service_not_configured"})

      {:error, _reason} ->
        conn |> put_status(:bad_gateway) |> json(%{error: "cloudflare_error"})
    end
  end

  # POST /api/vod/documents
  def create(conn, params) do
    user = conn.assigns.current_user
    title = string_param(params, "title")
    uid = string_param(params, "uid")

    with :ok <- require_present(title, :title_required),
         :ok <- require_present(uid, :uid_required),
         {:ok, org_id} <- resolve_org(user) do
      attrs = %{
        title: title,
        url: StellarMs.hls_url_for(uid) || fallback_hls(uid),
        mime_type: normalize_mime(params["mime_type"]),
        description: blank_to_nil(params["description"]),
        course_id: nil,
        user_id: user.id,
        organization_id: org_id
      }

      changeset = Ash.Changeset.for_create(Document, :create, attrs)

      case Ash.create(changeset, authorize?: false) do
        {:ok, doc} ->
          conn |> put_status(:created) |> json(%{data: document_json(doc)})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "create_failed"})
      end
    else
      {:error, :title_required} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "title_required"})

      {:error, :uid_required} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "uid_required"})

      {:error, :no_organization} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "no_organization"})
    end
  end

  # GET /api/vod/documents/:uid/status
  def status(conn, %{"uid" => uid}) do
    cond do
      not owns_uid?(conn.assigns.current_user, uid) ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      true ->
        case StellarMs.get_video(uid) do
          {:ok, info} ->
            json(conn, %{
              data: %{
                uid: info.uid,
                state: info.state,
                ready_to_stream: info.ready_to_stream,
                duration_seconds: info.duration_seconds,
                hls_url: info.hls_url,
                thumbnail_url: info.thumbnail_url,
                error_message: info.error_message
              }
            })

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          {:error, :not_configured} ->
            conn
            |> put_status(:service_unavailable)
            |> json(%{error: "video_service_not_configured"})

          {:error, _reason} ->
            conn |> put_status(:bad_gateway) |> json(%{error: "cloudflare_error"})
        end
    end
  end

  # --- helpers ---

  defp require_present("", reason), do: {:error, reason}
  defp require_present(_value, _reason), do: :ok

  # Org tenant dokumen = org aktif user (member aktif pertama). Wajib (Document).
  defp resolve_org(user) do
    case Authz.active_org_id(nil, user) do
      org_id when is_binary(org_id) -> {:ok, org_id}
      _ -> {:error, :no_organization}
    end
  end

  # Status hanya boleh untuk video yang uid-nya ter-referensi oleh Document milik
  # si pemanggil (miliknya atau se-org). Mencegah IDOR lintas-tenant ke pool
  # Cloudflare akun. uid tersimpan di dalam `url` (HLS), jadi cocokkan via contains.
  defp owns_uid?(user, uid) when is_binary(uid) and uid != "" do
    org_ids = StudentScope.org_ids(user)

    Document
    |> Ash.Query.filter(
      contains(url, ^uid) and (user_id == ^user.id or organization_id in ^org_ids)
    )
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  defp owns_uid?(_user, _uid), do: false

  # Ambil nilai string dari params HANYA bila memang biner; selain itu "" (invalid).
  # Menghindari 500 saat klien mengirim tipe non-string (mis. objek/array JSON).
  defp string_param(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) -> String.trim(value)
      _ -> ""
    end
  end

  # mime_type menandai jenis media; default video/mp4 bila klien tak mengirim.
  defp normalize_mime(value) do
    case blank_to_nil(value) do
      nil -> "video/mp4"
      mime -> mime
    end
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_value), do: nil

  defp document_json(doc) do
    %{
      id: doc.id,
      title: doc.title,
      url: doc.url,
      mime_type: doc.mime_type,
      description: doc.description,
      course_id: doc.course_id,
      created_at: doc.created_at
    }
  end
end
