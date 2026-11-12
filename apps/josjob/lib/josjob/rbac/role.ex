defmodule Josjob.Rbac.Role do
  @moduledoc "Role. organization_id NULL = role global/sistem; terisi = custom per-org."
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Rbac

  postgres do
    table("roles")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:key, :string, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:display_name, :string, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:is_system, :boolean, allow_nil?: false, default: false, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)

    # Audit trail: id user pembuat & pengubah terakhir (diisi otomatis dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)
  end

  relationships do
    # NULL = role global (berlaku semua tenant).
    belongs_to :organization, Josjob.Orgs.Organization do
      allow_nil?(true)
      public?(true)
    end
  end

  identities do
    # NULLS NOT DISTINCT: key role global (org NULL) juga unik.
    identity(:unique_org_key, [:organization_id, :key], nils_distinct?: false)
  end

  changes do
    change(Josjob.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:key, :name, :display_name, :description, :is_system, :organization_id])
  end
end
