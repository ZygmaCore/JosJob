defmodule JosjobLrn.Learning.Course do
  @moduledoc """
  Course (mis. \"Go Programming\"). Multi-tenant (M:N org), berkategori section +
  banyak industry. Pengajar TIDAK di sini — ada di Class. Material = dokumen
  (JosjobDoc) dengan `course_id` == id course ini.
  """
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Learning

  postgres do
    table("courses")
    repo(Josjob.Repo)

    references do
      reference(:section, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:is_active, :boolean, allow_nil?: false, default: true, public?: true)

    # Visibility: true = public (every student sees it in the catalog);
    # false = org-scoped (only members of an org the course is shared to).
    attribute(:is_public, :boolean, allow_nil?: false, default: false, public?: true)

    # Price in the smallest currency unit (e.g. cents). nil or 0 = FREE
    # (one-tap enrol); > 0 = paid (Stripe card required before enrolling).
    attribute(:price_cents, :integer, public?: true)
    attribute(:currency, :string, allow_nil?: false, default: "usd", public?: true)

    # Audit trail: id user pembuat & pengubah terakhir (diisi dari actor).
    attribute(:created_by, :uuid, allow_nil?: true, public?: true)
    attribute(:updated_by, :uuid, allow_nil?: true, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :section, JosjobLrn.Learning.Section do
      allow_nil?(false)
      public?(true)
    end

    has_many :classes, JosjobLrn.Learning.Class do
      public?(true)
    end

    many_to_many :organizations, Josjob.Orgs.Organization do
      through(JosjobLrn.Learning.CourseOrganization)
      source_attribute_on_join_resource(:course_id)
      destination_attribute_on_join_resource(:organization_id)
      public?(true)
    end

    many_to_many :industries, Josjob.Orgs.Industry do
      through(JosjobLrn.Learning.CourseIndustry)
      source_attribute_on_join_resource(:course_id)
      destination_attribute_on_join_resource(:industry_id)
      public?(true)
    end
  end

  changes do
    change(Josjob.Changes.StampActor)
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    default_accept([
      :title,
      :description,
      :is_active,
      :is_public,
      :price_cents,
      :currency,
      :section_id
    ])
  end
end
