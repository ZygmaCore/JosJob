defmodule Josjob.Orgs.Skill do
  @moduledoc "Master data skill. Terkait ke satu industri (opsional) via industry_id."
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Orgs

  postgres do
    table("skills")
    repo(Josjob.Repo)
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
    belongs_to :industry, Josjob.Orgs.Industry do
      allow_nil?(true)
      public?(true)
    end
  end

  identities do
    identity(:unique_name, [:name])
  end

  changes do
    change(Josjob.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:name, :industry_id])
  end
end
