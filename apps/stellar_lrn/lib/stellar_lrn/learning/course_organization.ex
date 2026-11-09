defmodule StellarLrn.Learning.CourseOrganization do
  @moduledoc "Join course ↔ organization (tenant yang memakai course)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("course_organizations")
    repo(Stellar.Repo)

    references do
      reference(:course, on_delete: :delete)
      reference(:organization, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to :course, StellarLrn.Learning.Course do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_course_organization, [:course_id, :organization_id])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:course_id, :organization_id])
  end
end
