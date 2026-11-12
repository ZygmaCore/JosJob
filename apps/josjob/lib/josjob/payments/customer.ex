defmodule Josjob.Payments.Customer do
  @moduledoc """
  Pemetaan Customer Stripe untuk tiap `Josjob.Accounts.User` (1:1).

  `user_id` disimpan sebagai referensi lunak (bukan relasi/ FK Ash lintas-domain)
  agar domain Payments tetap longgar terhadap domain Accounts.
  """
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Payments

  postgres do
    table("payment_customers")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:stripe_customer_id, :string, allow_nil?: false, public?: true)
    attribute(:user_id, :uuid, public?: true)
    attribute(:email, :string, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_stripe_customer_id, [:stripe_customer_id])
    identity(:unique_user, [:user_id])
  end

  relationships do
    has_many(:payments, Josjob.Payments.Payment)
    has_many(:subscriptions, Josjob.Payments.Subscription)
  end

  actions do
    default_accept([:stripe_customer_id, :user_id, :email])
    defaults([:create, :read, :update, :destroy])

    create :upsert do
      upsert?(true)
      upsert_identity(:unique_stripe_customer_id)
      accept([:stripe_customer_id, :user_id, :email])
    end
  end
end
