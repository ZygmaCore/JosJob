defmodule JosjobDoc.Documents do
  @moduledoc """
  Domain bank dokumen. Dua resource:

    * `Document`            — dokumen (polymorphic course/user, lihat resource).
    * `DocumentAccessGrant` — *share* per-user ala Google Docs: pemilik dokumen
      menentukan siapa yang boleh mengaksesnya (flag `allow` + masa berlaku).

  Enforcement lewat query-scope (bukan Ash policy global) — cikal-bakal RBAC.
  """
  use Ash.Domain

  require Ash.Query
  alias JosjobDoc.Documents.{Document, DocumentAccessGrant}
  alias Josjob.Rbac.{Role, MembershipRole}
  alias Josjob.Orgs.Membership

  resources do
    resource(Document)
    resource(DocumentAccessGrant)
  end

  # Role yang dihitung sebagai "admin organisasi" (dapat dikonfigurasi).
  @org_admin_roles ["coordinator"]

  @doc """
  Daftar dokumen yang boleh dilihat `current_user` (urut terbaru), sebagai union:

    * superuser  → semua dokumen
    * admin-org  → semua dokumen di org tempat ia admin (role ∈ #{inspect(@org_admin_roles)})
    * share      → dokumen yang di-*share* aktif kepadanya (`allow` + dalam rentang waktu)
    * selalu     → dokumen miliknya (`user_id == current_user.id`)
  """
  def visible_to(%{is_superuser: true}) do
    Document |> Ash.Query.sort(created_at: :desc) |> Ash.read!(authorize?: false)
  end

  def visible_to(%{id: uid}) when is_binary(uid) do
    admin_org_ids = admin_org_ids(uid)
    granted_ids = active_grant_document_ids(uid)

    Document
    |> Ash.Query.filter(
      user_id == ^uid or organization_id in ^admin_org_ids or id in ^granted_ids
    )
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  def visible_to(_), do: []

  @doc """
  Boleh **mengakses** (melihat) dokumen ini?

    * superuser  → ya
    * pemilik    → ya
    * admin-org  → ya (dokumen se-org tempat ia admin)
    * share aktif→ ya (`allow` + dalam rentang waktu)
  """
  def can_access?(%{is_superuser: true}, %Document{}), do: true

  def can_access?(%{id: uid}, %Document{} = document) when is_binary(uid) do
    uid == document.user_id or
      document.organization_id in admin_org_ids(uid) or
      document.id in active_grant_document_ids(uid)
  end

  def can_access?(_user, _document), do: false

  @doc """
  Boleh **mengelola** daftar share dokumen (menambah/mencabut akses)?
  Pemilik | admin-org | superuser.
  """
  def can_manage_grants?(%{is_superuser: true}, %Document{}), do: true

  def can_manage_grants?(%{id: uid}, %Document{user_id: owner_id, organization_id: org_id})
      when is_binary(uid) do
    uid == owner_id or org_id in admin_org_ids(uid)
  end

  def can_manage_grants?(_user, _document), do: false

  @doc "Ambil satu `Document` by id (tanpa otorisasi Ash); nil bila tak ada / id invalid."
  def get_document(id) when is_binary(id) do
    case Ash.get(Document, id, authorize?: false) do
      {:ok, document} -> document
      _ -> nil
    end
  end

  def get_document(_), do: nil

  @doc "Daftar share (grant) sebuah dokumen — user penerima sudah di-load, urut terbaru."
  def grants_for(document_id) when is_binary(document_id) do
    DocumentAccessGrant
    |> Ash.Query.filter(document_id == ^document_id)
    |> Ash.Query.load(:user)
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  def grants_for(_), do: []

  @doc "Id dokumen yang saat ini di-*share* aktif ke `uid` (`allow` + di dalam rentang waktu)."
  def active_grant_document_ids(uid) when is_binary(uid) do
    now = DateTime.utc_now()

    DocumentAccessGrant
    |> Ash.Query.filter(
      user_id == ^uid and allow == true and
        (is_nil(valid_from) or valid_from <= ^now) and
        (is_nil(valid_until) or valid_until >= ^now)
    )
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.document_id)
    |> Enum.uniq()
  end

  def active_grant_document_ids(_), do: []

  @doc "Id organisasi tempat `uid` menjadi admin-org (member aktif ber-role admin)."
  def admin_org_ids(uid) do
    role_ids =
      Role
      |> Ash.Query.filter(key in ^@org_admin_roles)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if role_ids == [] do
      []
    else
      memberships =
        Membership
        |> Ash.Query.filter(user_id == ^uid and status == :active)
        |> Ash.read!(authorize?: false)

      membership_ids = Enum.map(memberships, & &1.id)

      admin_membership_ids =
        MembershipRole
        |> Ash.Query.filter(membership_id in ^membership_ids and role_id in ^role_ids)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.membership_id)
        |> Enum.uniq()

      memberships
      |> Enum.filter(&(&1.id in admin_membership_ids))
      |> Enum.map(& &1.organization_id)
      |> Enum.uniq()
    end
  end
end
