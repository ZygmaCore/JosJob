defmodule StellarLrn.Learning.SectionOrganization do
  @moduledoc "Join section ↔ organization (tenant yang punya section)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("section_organizations")
    repo(Stellar.Repo)

    references do
      reference(:section, on_delete: :delete)
      reference(:organization, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to :section, StellarLrn.Learning.Section do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_section_organization, [:section_id, :organization_id])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:section_id, :organization_id])
  end
end
