defmodule JosjobLrn.Coaching.Slot do
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Coaching

  postgres do
    table "coaching_slots"
    repo Josjob.Repo

    references do
      reference :coach, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :starts_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :ends_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :enabled, :boolean, allow_nil?: false, default: true, public?: true
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :coach, JosjobLrn.Coaching.Profile do
      allow_nil? false
      public? true
    end

    has_many :bookings, JosjobLrn.Coaching.Booking do
      public? true
    end
  end

  identities do
    identity :unique_coach_start, [:coach_id, :starts_at]
  end

  actions do
    defaults [:read]

    create :create do
      accept []
    end

    update :close do
      accept []
      change set_attribute(:enabled, false)
    end
  end
end
