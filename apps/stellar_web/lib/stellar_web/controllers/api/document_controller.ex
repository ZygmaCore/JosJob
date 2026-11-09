defmodule StellarWeb.Api.DocumentController do
  @moduledoc """
  API dokumen untuk klien mobile (Flutter): melihat dokumen yang bisa diakses
  dan **mengelola akses ala Google Docs** — pemilik (uploader) menentukan siapa
  yang boleh mengakses dokumennya via daftar *share* (grant), dengan flag `allow`
  dan masa berlaku (`valid_from`/`valid_until`) yang bisa dikonfigurasi.

  Semua endpoint butuh Bearer access token (pipeline `:api_auth`). Otorisasi
  dilakukan inline (bukan plug browser yang me-redirect): superuser & admin-org
  (role "coordinator") mengakses/mengelola dokumen se-org; pemilik mengelola
  dokumennya; penerima share aktif dapat mengakses.

    * `POST   /api/documents/upload-url`           → presigned URL upload file (non-video)
    * `POST   /api/documents`                      → simpan Document (course_id null)
    * `GET    /api/documents`                      → dokumen yang bisa saya akses
    * `GET    /api/documents/:id`                  → satu dokumen (bila boleh akses)
    * `GET    /api/documents/:id/grants`           → daftar share (pengelola saja)
    * `POST   /api/documents/:id/grants`           → share via email (upsert; pengelola)
    * `DELETE /api/documents/:id/grants/:grant_id` → cabut share (pengelola)
  """
  use StellarWeb, :controller

  require Ash.Query
  alias Stellar.Authz
  alias StellarDoc.Documents
  alias StellarDoc.Documents.{Document, DocumentAccessGrant}

  # GET /api/documents
  def index(conn, _params) do
    user = conn.assigns.current_user
    ctx = access_ctx(user)
    docs = Documents.visible_to(user)
    json(conn, %{data: Enum.map(docs, &document_json(&1, ctx))})
  end

  # GET /api/documents/:id
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case fetch_document(id) do
      nil ->
        not_found(conn)

      doc ->
        if Documents.can_access?(user, doc),
          do: json(conn, %{data: document_json(doc, access_ctx(user))}),
          else: not_found(conn)
    end
  end

  # POST /api/documents/upload-url
  # Mint presigned PUT URL (object storage) untuk upload file NON-video (pdf/doc/…).
  # Kelayakan (punya org) dicek DI SINI sebelum bytes di-upload.
  def create_upload(conn, params) do
    with {:ok, _org_id} <- resolve_org(conn.assigns.current_user),
         {:ok, upload} <-
           StellarMs.Storage.create_presigned_upload(filename: string_param(params, "filename")) do
      json(conn, %{
        data: %{
          upload_url: upload.upload_url,
          method: upload.method,
          key: upload.key,
          public_url: upload.public_url
        }
      })
    else
      {:error, :no_organization} -> error(conn, :no_organization)
      {:error, :not_configured} -> service_unavailable(conn, "storage_not_configured")
      {:error, _reason} -> bad_gateway(conn, "storage_error")
    end
  end

  # POST /api/documents
  # Simpan Document (course_id null = dokumen lepas). `url` = URL publik objek
  # (video: HLS Cloudflare via /api/vod; non-video: hasil presigned upload).
  def create(conn, params) do
    user = conn.assigns.current_user
    title = string_param(params, "title")
    url = string_param(params, "url")

    with :ok <- require_present(title, :title_required),
         :ok <- require_present(url, :url_required),
         {:ok, org_id} <- resolve_org(user) do
      attrs = %{
        title: title,
        url: url,
        mime_type: blank_to_nil(params["mime_type"]),
        description: blank_to_nil(params["description"]),
        course_id: nil,
        user_id: user.id,
        organization_id: org_id
      }

      case Ash.create(Ash.Changeset.for_create(Document, :create, attrs), authorize?: false) do
        {:ok, doc} ->
          conn |> put_status(:created) |> json(%{data: document_json(doc, access_ctx(user))})

        {:error, _} ->
          error(conn, :create_failed)
      end
    else
      {:error, :title_required} -> error(conn, :title_required)
      {:error, :url_required} -> error(conn, :url_required)
      {:error, :no_organization} -> error(conn, :no_organization)
    end
  end

  # GET /api/documents/:id/grants
  def grants_index(conn, %{"id" => id}) do
    case load_manageable(conn, id) do
      {:ok, doc, _actor} ->
        grants = Documents.grants_for(doc.id)
        json(conn, %{data: Enum.map(grants, &grant_json/1)})

      {:error, status} ->
        error(conn, status)
    end
  end

  # POST /api/documents/:id/grants
  def create_grant(conn, %{"id" => id} = params) do
    email = string_param(params, "email")

    with {:ok, doc, actor} <- load_manageable(conn, id),
         :ok <- require_present(email, :email_required),
         {:ok, grantee} <- fetch_user(email),
         :ok <- refute_owner(doc, grantee),
         existing = existing_grant(doc.id, grantee.id),
         {:ok, valid_from} <- resolve_datetime(params, "valid_from", existing),
         {:ok, valid_until} <- resolve_datetime(params, "valid_until", existing),
         :ok <- validate_window(valid_from, valid_until) do
      # Upsert overwrites every upsert_field, so a field the caller OMITS must
      # keep its stored value — otherwise a partial update (e.g. changing only
      # the expiry) would silently reset `allow`/`valid_from` to their
      # permissive defaults, re-enabling a soft-revoked or future-dated grant.
      attrs = %{
        document_id: doc.id,
        user_id: grantee.id,
        allow: resolve_allow(params, existing),
        valid_from: valid_from,
        valid_until: valid_until,
        granted_by_id: actor.id
      }

      changeset = Ash.Changeset.for_create(DocumentAccessGrant, :upsert, attrs)

      case Ash.create(changeset, authorize?: false) do
        {:ok, grant} ->
          grant = Ash.load!(grant, :user, authorize?: false)
          conn |> put_status(:created) |> json(%{data: grant_json(grant)})

        {:error, _} ->
          error(conn, :create_failed)
      end
    else
      {:error, status} -> error(conn, status)
    end
  end

  # DELETE /api/documents/:id/grants/:grant_id
  def delete_grant(conn, %{"id" => id, "grant_id" => grant_id}) do
    with {:ok, doc, _actor} <- load_manageable(conn, id),
         {:ok, grant} <- fetch_grant(doc.id, grant_id) do
      case Ash.destroy(grant, authorize?: false) do
        :ok -> json(conn, %{data: %{deleted: true}})
        {:ok, _} -> json(conn, %{data: %{deleted: true}})
        {:error, _} -> error(conn, :delete_failed)
      end
    else
      {:error, status} -> error(conn, status)
    end
  end

  # --- authorization / loading ---

  # Muat dokumen yang daftar share-nya boleh DIKELOLA oleh pemanggil.
  # 404 bila tak ada / tak boleh akses (sembunyikan keberadaan → anti-IDOR);
  # 403 bila boleh akses tapi bukan pengelola.
  defp load_manageable(conn, id) do
    user = conn.assigns.current_user

    case fetch_document(id) do
      nil ->
        {:error, :not_found}

      doc ->
        cond do
          Documents.can_manage_grants?(user, doc) -> {:ok, doc, user}
          Documents.can_access?(user, doc) -> {:error, :forbidden}
          true -> {:error, :not_found}
        end
    end
  end

  defp fetch_document(id) when is_binary(id) do
    if valid_uuid?(id), do: Documents.get_document(id), else: nil
  end

  defp fetch_document(_), do: nil

  defp fetch_grant(doc_id, grant_id) when is_binary(grant_id) do
    if valid_uuid?(grant_id) do
      DocumentAccessGrant
      |> Ash.Query.filter(id == ^grant_id and document_id == ^doc_id)
      |> Ash.Query.limit(1)
      |> Ash.read!(authorize?: false)
      |> List.first()
      |> case do
        nil -> {:error, :grant_not_found}
        grant -> {:ok, grant}
      end
    else
      {:error, :grant_not_found}
    end
  end

  defp fetch_grant(_doc_id, _grant_id), do: {:error, :grant_not_found}

  defp fetch_user(email) do
    Stellar.Accounts.User
    |> Ash.Query.filter(email == ^email)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
    |> case do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  # Pemilik sudah punya akses penuh; jangan buat baris grant untuknya.
  defp refute_owner(%{user_id: owner_id}, %{id: owner_id}), do: {:error, :cannot_grant_owner}
  defp refute_owner(_doc, _grantee), do: :ok

  # Grant yang ada untuk (dokumen, user) — untuk mempertahankan field yang tak
  # dikirim pada partial update. nil bila belum pernah di-share.
  defp existing_grant(doc_id, user_id) do
    DocumentAccessGrant
    |> Ash.Query.filter(document_id == ^doc_id and user_id == ^user_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  # Field waktu dikirim → parse; tak dikirim → pertahankan nilai yang tersimpan.
  defp resolve_datetime(params, key, existing) do
    if Map.has_key?(params, key),
      do: parse_datetime(params[key]),
      else: {:ok, existing_field(existing, key)}
  end

  defp existing_field(nil, _key), do: nil
  defp existing_field(grant, "valid_from"), do: grant.valid_from
  defp existing_field(grant, "valid_until"), do: grant.valid_until

  # `allow` dikirim → parse; tak dikirim → pertahankan (atau true untuk grant baru).
  defp resolve_allow(params, existing) do
    cond do
      Map.has_key?(params, "allow") -> parse_allow(params["allow"])
      existing != nil -> existing.allow
      true -> true
    end
  end

  # --- per-request context for relationship/can_manage labels ---

  defp access_ctx(%{is_superuser: true}), do: %{superuser: true}

  defp access_ctx(%{id: uid}) when is_binary(uid) do
    %{superuser: false, uid: uid, admin_org_ids: Documents.admin_org_ids(uid)}
  end

  defp access_ctx(_) do
    %{superuser: false, uid: nil, admin_org_ids: []}
  end

  # --- JSON ---

  defp document_json(doc, ctx) do
    %{
      id: doc.id,
      title: doc.title,
      url: doc.url,
      mime_type: doc.mime_type,
      description: doc.description,
      course_id: doc.course_id,
      owner_id: doc.user_id,
      organization_id: doc.organization_id,
      relationship: relationship(doc, ctx),
      can_manage: can_manage?(doc, ctx),
      created_at: doc.created_at
    }
  end

  defp relationship(_doc, %{superuser: true}), do: "admin"

  defp relationship(doc, ctx) do
    cond do
      doc.user_id == ctx.uid -> "owner"
      doc.organization_id in ctx.admin_org_ids -> "org"
      true -> "shared"
    end
  end

  defp can_manage?(_doc, %{superuser: true}), do: true

  defp can_manage?(doc, ctx) do
    doc.user_id == ctx.uid or doc.organization_id in ctx.admin_org_ids
  end

  defp grant_json(grant) do
    %{
      id: grant.id,
      document_id: grant.document_id,
      user_id: grant.user_id,
      email: grantee_email(grant),
      full_name: grantee_name(grant),
      allow: grant.allow,
      valid_from: grant.valid_from,
      valid_until: grant.valid_until,
      active: grant_active?(grant),
      created_at: grant.created_at
    }
  end

  defp grantee_email(%{user: %{email: email}}) when not is_nil(email), do: to_string(email)
  defp grantee_email(_), do: nil

  defp grantee_name(%{user: %{full_name: name}}), do: name
  defp grantee_name(_), do: nil

  defp grant_active?(%{allow: false}), do: false

  defp grant_active?(%{valid_from: from, valid_until: until}) do
    now = DateTime.utc_now()
    on_or_after?(now, from) and on_or_before?(now, until)
  end

  defp on_or_after?(_now, nil), do: true
  defp on_or_after?(now, from), do: DateTime.compare(now, from) != :lt

  defp on_or_before?(_now, nil), do: true
  defp on_or_before?(now, until), do: DateTime.compare(now, until) != :gt

  # --- param parsing ---

  defp string_param(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) -> String.trim(value)
      _ -> ""
    end
  end

  defp require_present("", reason), do: {:error, reason}
  defp require_present(_value, _reason), do: :ok

  # Org tenant dokumen = org aktif user (member aktif pertama). Wajib (Document).
  defp resolve_org(user) do
    case Authz.active_org_id(nil, user) do
      org_id when is_binary(org_id) -> {:ok, org_id}
      _ -> {:error, :no_organization}
    end
  end

  defp blank_to_nil(v) when is_binary(v) do
    case String.trim(v) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  # Default: izinkan. Hanya false eksplisit yang menonaktifkan.
  defp parse_allow(false), do: false
  defp parse_allow("false"), do: false
  defp parse_allow(_), do: true

  defp parse_datetime(nil), do: {:ok, nil}
  defp parse_datetime(""), do: {:ok, nil}

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(String.trim(value)) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, :invalid_datetime}
    end
  end

  defp parse_datetime(_), do: {:error, :invalid_datetime}

  defp validate_window(nil, _until), do: :ok
  defp validate_window(_from, nil), do: :ok

  defp validate_window(from, until) do
    if DateTime.compare(from, until) == :gt, do: {:error, :invalid_window}, else: :ok
  end

  defp valid_uuid?(value) when is_binary(value), do: match?({:ok, _}, Ecto.UUID.cast(value))
  defp valid_uuid?(_), do: false

  # --- responses ---

  defp error(conn, :not_found), do: not_found(conn)
  defp error(conn, :grant_not_found), do: not_found(conn)
  defp error(conn, :forbidden), do: forbidden(conn)
  defp error(conn, reason), do: unprocessable(conn, to_string(reason))

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})
  defp forbidden(conn), do: conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

  defp unprocessable(conn, reason),
    do: conn |> put_status(:unprocessable_entity) |> json(%{error: reason})

  defp service_unavailable(conn, reason),
    do: conn |> put_status(:service_unavailable) |> json(%{error: reason})

  defp bad_gateway(conn, reason),
    do: conn |> put_status(:bad_gateway) |> json(%{error: reason})
end
