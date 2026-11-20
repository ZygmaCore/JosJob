defmodule JosjobLrn.Certificates.Certificate do
  use Ash.Resource,
    otp_app: :josjob_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: JosjobLrn.Certificates

  postgres do
    table "learner_certificates"
    repo Josjob.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string,
      allow_nil?: false,
      public?: true,
      constraints: [min_length: 2, max_length: 200]

    attribute :issuer, :string,
      allow_nil?: false,
      public?: true,
      constraints: [min_length: 2, max_length: 200]

    attribute :issued_on, :date, public?: true
    attribute :expires_on, :date, public?: true
    attribute :credential_id, :string, public?: true, constraints: [max_length: 200]
    attribute :credential_url, :string, public?: true, constraints: [max_length: 2000]
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Josjob.Accounts.User do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :issuer, :issued_on, :expires_on, :credential_id, :credential_url]
    end

    update :update do
      accept [:title, :issuer, :issued_on, :expires_on, :credential_id, :credential_url]
    end
  end
end
