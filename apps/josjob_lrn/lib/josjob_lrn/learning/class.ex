defmodule JosjobLrn.Learning.Class do
  @moduledoc """
  Kelas: satu penyelenggaraan course oleh SATU pengajar (instructor), dengan
  jadwal (daftar sesi) + kapasitas slot (nil = tak terbatas). Milik satu tenant.
  """
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Learning

  postgres do
    table("classes")
    repo(Josjob.Repo)

    references do
      reference(:course, on_delete: :delete)
      reference(:organization, on_delete: :delete)
      reference(:instructor, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
    # Daftar sesi eksplisit: [%{"date" => "2026-08-01", "start" => "09:00", "end" => "10:00"}].
    attribute(:schedule, {:array, :map}, allow_nil?: false, default: [], public?: true)
    # null = slot tak terbatas.
    attribute(:capacity, :integer, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :course, JosjobLrn.Learning.Course do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organization, Josjob.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :instructor, Josjob.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    has_many :enrollments, JosjobLrn.Learning.Enrollment do
      public?(true)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:title, :schedule, :capacity, :course_id, :organization_id, :instructor_id])
  end
end
