defmodule Josjob.Orgs.Organization do
  @moduledoc "Organisasi (tenant). `owner` = pembuat; keanggotaan via memberships."
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Orgs

  postgres do
    table("organizations")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:phone, :string, public?: true)
    attribute(:address, :string, public?: true)
    attribute(:additional_info, :string, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)

    # Audit trail: id user pembuat & pengubah terakhir (diisi otomatis dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)
  end

  relationships do
    belongs_to :owner, Josjob.Accounts.User do
      source_attribute(:user_id)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :industry, Josjob.Orgs.Industry do
      allow_nil?(true)
      public?(true)
    end
  end

  changes do
    change(Josjob.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:name, :phone, :address, :additional_info, :user_id, :industry_id])
  end
end
