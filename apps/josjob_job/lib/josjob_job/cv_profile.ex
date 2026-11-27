defmodule JosjobJob.CvProfile do
  @moduledoc "Candidate-owned CV presentation and an explicitly selected resume document."
  use Ash.Resource, otp_app: :josjob_job, domain: JosjobJob, data_layer: AshPostgres.DataLayer

  postgres do
    table("candidate_cv_profiles")
    repo(Josjob.Repo)

    references do
      reference(:user, on_delete: :delete)
      reference(:resume_document, on_delete: :nilify)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:full_name, :string, public?: true, constraints: [min_length: 2, max_length: 120])
    attribute(:headline, :string, public?: true, constraints: [max_length: 200])
    attribute(:summary, :string, public?: true, constraints: [max_length: 4000])
    attribute(:cv_facts, :map)
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:user, Josjob.Accounts.User, allow_nil?: false)
    belongs_to(:resume_document, JosjobDoc.Documents.Document)
  end

  identities do
    identity(:unique_cv_user, [:user_id])
  end

  actions do
    defaults([:read])

    create :create do
      accept([:full_name, :headline, :summary])
    end

    update :update do
      accept([:full_name, :headline, :summary])
    end
  end
end
