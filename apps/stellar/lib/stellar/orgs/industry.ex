defmodule Stellar.Orgs.Industry do
  @moduledoc "Industri (data referensi untuk organizations)."
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Orgs

  postgres do
    table("industries")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)

    # Audit trail: id user pembuat & pengubah terakhir (diisi otomatis dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)
  end

  relationships do
    # Hierarki industri (opsional): industri induk. NULL = industri level atas.
    belongs_to :parent, Stellar.Orgs.Industry do
      source_attribute(:parent_id)
      allow_nil?(true)
      public?(true)
    end
  end

  identities do
    identity(:unique_name, [:name])
  end

  changes do
    change(Stellar.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:name, :parent_id])
  end
end
