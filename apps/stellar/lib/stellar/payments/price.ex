defmodule Stellar.Payments.Price do
  @moduledoc """
  Mirror Price Stripe. `recurring_interval` bernilai nil untuk harga sekali bayar,
  atau "day"/"week"/"month"/"year" untuk langganan. `unit_amount` dalam satuan
  terkecil mata uang.
  """
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Payments

  postgres do
    table("payment_prices")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:stripe_price_id, :string, allow_nil?: false, public?: true)
    attribute(:unit_amount, :integer, public?: true)
    attribute(:currency, :string, default: "usd", public?: true)
    attribute(:recurring_interval, :string, public?: true)
    attribute(:active, :boolean, default: true, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_stripe_price_id, [:stripe_price_id])
  end

  relationships do
    belongs_to :product, Stellar.Payments.Product do
      public?(true)
      attribute_writable?(true)
    end
  end

  actions do
    default_accept([
      :stripe_price_id,
      :unit_amount,
      :currency,
      :recurring_interval,
      :active,
      :product_id
    ])

    defaults([:create, :read, :update, :destroy])

    create :upsert do
      upsert?(true)
      upsert_identity(:unique_stripe_price_id)

      accept([
        :stripe_price_id,
        :unit_amount,
        :currency,
        :recurring_interval,
        :active,
        :product_id
      ])
    end
  end
end
