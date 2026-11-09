defmodule StellarLrn.Learning.Section do
  @moduledoc "Section / jurusan (mis. \"Technology Information\"). Multi-tenant (M:N org)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("sections")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:is_active, :boolean, allow_nil?: false, default: true, public?: true)

    # Audit trail: id user pembuat & pengubah terakhir (diisi dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :courses, StellarLrn.Learning.Course do
      public?(true)
    end

    many_to_many :organizations, Stellar.Orgs.Organization do
      through(StellarLrn.Learning.SectionOrganization)
      source_attribute_on_join_resource(:section_id)
      destination_attribute_on_join_resource(:organization_id)
      public?(true)
    end
  end

  changes do
    change(Stellar.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:name, :description, :is_active])
  end
end
