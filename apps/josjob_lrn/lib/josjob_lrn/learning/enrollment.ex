defmodule JosjobLrn.Learning.Enrollment do
  @moduledoc "Pendaftaran siswa ke sebuah Class. Unik per (class, student)."
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Learning

  postgres do
    table("enrollments")
    repo(Josjob.Repo)

    references do
      reference(:class, on_delete: :delete)
      reference(:student, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :active,
      constraints: [one_of: [:active, :completed]],
      public?: true
    )

    attribute(:enrolled_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true
    )

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :class, JosjobLrn.Learning.Class do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :student, Josjob.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_class_student, [:class_id, :student_id])
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      accept([:class_id, :student_id, :status])
      change(JosjobLrn.Learning.Changes.CheckCapacity)
    end

    update :set_status do
      accept([:status])
    end
  end
end
