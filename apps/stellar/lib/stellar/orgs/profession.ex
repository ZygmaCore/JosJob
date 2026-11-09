defmodule Stellar.Orgs.Profession do
  @moduledoc "Master data profesi (data referensi untuk onboarding)."
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Orgs

  postgres do
    table("professions")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_name, [:name])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:name])
  end
end
