defmodule JosjobLrn.Coaching.Profile do
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Coaching

  postgres do
    table "coaching_profiles"
    repo Josjob.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :display_name, :string,
      allow_nil?: false,
      public?: true,
      constraints: [min_length: 2, max_length: 100]

    attribute :headline, :string,
      allow_nil?: false,
      public?: true,
      constraints: [min_length: 3, max_length: 180]

    attribute :bio, :string,
      allow_nil?: false,
      public?: true,
      constraints: [min_length: 10, max_length: 4000]

    attribute :expertise, {:array, :string},
      allow_nil?: false,
      default: [],
      public?: true,
      constraints: [max_length: 15, items: [max_length: 60]]

    attribute :session_minutes, :integer,
      allow_nil?: false,
      default: 30,
      public?: true,
      constraints: [min: 15, max: 120]

    attribute :status, :atom,
      allow_nil?: false,
      default: :pending,
      public?: true,
      constraints: [one_of: [:pending, :approved, :suspended]]

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Josjob.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_coach_user, [:user_id]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:display_name, :headline, :bio, :expertise, :session_minutes]
    end

    update :update do
      accept [:display_name, :headline, :bio, :expertise, :session_minutes]
    end

    update :set_status do
      accept [:status]
    end
  end
end
