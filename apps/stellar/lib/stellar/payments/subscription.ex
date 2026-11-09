defmodule Stellar.Payments.Subscription do
  @moduledoc """
  Mirror Subscription Stripe (langganan berulang). `status` menyimpan status
  Stripe verbatim. `stripe_price_id` = price item pertama pada langganan.
  """
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Payments

  postgres do
    table("payment_subscriptions")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:stripe_subscription_id, :string, allow_nil?: false, public?: true)
    attribute(:status, :string, public?: true)
    attribute(:stripe_price_id, :string, public?: true)
    attribute(:current_period_end, :utc_datetime, public?: true)
    attribute(:cancel_at_period_end, :boolean, default: false, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_stripe_subscription_id, [:stripe_subscription_id])
  end

  relationships do
    belongs_to :customer, Stellar.Payments.Customer do
      public?(true)
      attribute_writable?(true)
    end
  end

  actions do
    default_accept([
      :stripe_subscription_id,
      :status,
      :stripe_price_id,
      :current_period_end,
      :cancel_at_period_end,
      :customer_id
    ])

    defaults([:create, :read, :update, :destroy])

    create :upsert do
      upsert?(true)
      upsert_identity(:unique_stripe_subscription_id)

      accept([
        :stripe_subscription_id,
        :status,
        :stripe_price_id,
        :current_period_end,
        :cancel_at_period_end,
        :customer_id
      ])
    end
  end
end
