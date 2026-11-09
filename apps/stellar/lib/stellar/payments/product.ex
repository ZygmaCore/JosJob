defmodule Stellar.Payments.Product do
  @moduledoc "Mirror Product Stripe (katalog produk/langganan)."
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    domain: Stellar.Payments

  postgres do
    table("payment_products")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:stripe_product_id, :string, allow_nil?: false, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:active, :boolean, default: true, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_stripe_product_id, [:stripe_product_id])
  end

  relationships do
    has_many(:prices, Stellar.Payments.Price)
  end

  actions do
    default_accept([:stripe_product_id, :name, :description, :active])
    defaults([:create, :read, :update, :destroy])

    create :upsert do
      upsert?(true)
      upsert_identity(:unique_stripe_product_id)
      accept([:stripe_product_id, :name, :description, :active])
    end
  end
end
