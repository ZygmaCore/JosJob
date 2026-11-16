defmodule JosjobLrn.Coaching.Booking do
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Coaching

  postgres do
    table "coaching_bookings"
    repo Josjob.Repo

    references do
      reference :coach, on_delete: :delete
      reference :slot, on_delete: :delete
      reference :learner, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :starts_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :ends_at, :utc_datetime_usec, allow_nil?: false, public?: true

    attribute :status, :atom,
      allow_nil?: false,
      default: :confirmed,
      public?: true,
      constraints: [one_of: [:confirmed, :cancelled, :completed]]

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :coach, JosjobLrn.Coaching.Profile do
      allow_nil? false
      public? true
    end

    belongs_to :slot, JosjobLrn.Coaching.Slot do
      allow_nil? false
    end

    belongs_to :learner, Josjob.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept []
    end

    update :set_status do
      accept [:status]
    end
  end
end
