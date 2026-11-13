defmodule JosjobLrn.Learning.CourseIndustry do
  @moduledoc "Join course ↔ industry (satu course bisa banyak industri)."
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Learning

  postgres do
    table("course_industries")
    repo(Josjob.Repo)

    references do
      reference(:course, on_delete: :delete)
      reference(:industry, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to :course, JosjobLrn.Learning.Course do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :industry, Josjob.Orgs.Industry do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_course_industry, [:course_id, :industry_id])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:course_id, :industry_id])
  end
end
