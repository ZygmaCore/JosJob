defmodule Stellar.Payments.Payment do
  @moduledoc """
  Catatan satu PaymentIntent Stripe (pembayaran sekali bayar). `status` menyimpan
  status Stripe verbatim (string) supaya tahan terhadap status baru dari Stripe.
  `amount` dalam satuan terkecil mata uang (mis. sen).
  """
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Payments

  postgres do
    table("payments")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:stripe_payment_intent_id, :string, allow_nil?: false, public?: true)
    attribute(:amount, :integer, public?: true)
    attribute(:currency, :string, default: "usd", public?: true)
    attribute(:status, :string, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_stripe_payment_intent_id, [:stripe_payment_intent_id])
  end

  relationships do
    belongs_to :customer, Stellar.Payments.Customer do
      public?(true)
      attribute_writable?(true)
    end
  end

  actions do
    default_accept([
      :stripe_payment_intent_id,
      :amount,
      :currency,
      :status,
      :description,
      :metadata,
      :customer_id
    ])

    defaults([:create, :read, :update, :destroy])

    create :upsert do
      upsert?(true)
      upsert_identity(:unique_stripe_payment_intent_id)

      accept([
        :stripe_payment_intent_id,
        :amount,
        :currency,
        :status,
        :description,
        :metadata,
        :customer_id
      ])
    end
  end
end
