defmodule Stellar.Rbac.Permission do
  @moduledoc "Katalog izin (di-seed dari kode). key = `resource:action`."
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Rbac

  postgres do
    table("permissions")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:key, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:category, :string, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)

    # Audit trail: id user pembuat & pengubah terakhir (diisi otomatis dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)
  end

  identities do
    identity(:unique_key, [:key])
  end

  changes do
    change(Stellar.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:key, :description, :category])
  end
end
