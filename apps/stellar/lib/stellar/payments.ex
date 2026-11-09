defmodule Stellar.Payments do
  @moduledoc """
  Domain pembayaran (Stripe). Menyimpan mirror objek Stripe — Customer, Product,
  Price, Payment, Subscription — plus log idempotensi webhook (`WebhookEvent`).

  Titik masuk publik dari sisi aplikasi adalah `Stellar.Payments.Billing`.
  Resource di sini TIDAK memakai policy Ash; akses dikontrol di lapisan web
  (plug `ApiAuth` untuk klien, `RequireAdmin` untuk CMS). Operasi sistem
  (Billing/WebhookHandler) memanggil action dengan `authorize?: false`.
  """
  use Ash.Domain

  resources do
    resource Stellar.Payments.Customer do
      define(:create_customer, action: :create)
      define(:upsert_customer, action: :upsert)
      define(:get_customer, action: :read, get_by: [:id])
      define(:get_customer_by_user, action: :read, get_by: [:user_id])
      define(:get_customer_by_stripe_id, action: :read, get_by: [:stripe_customer_id])
    end

    resource Stellar.Payments.Product do
      define(:upsert_product, action: :upsert)
    end

    resource Stellar.Payments.Price do
      define(:upsert_price, action: :upsert)
    end

    resource Stellar.Payments.Payment do
      define(:upsert_payment, action: :upsert)
      define(:get_payment_by_stripe_id, action: :read, get_by: [:stripe_payment_intent_id])
    end

    resource Stellar.Payments.Subscription do
      define(:upsert_subscription, action: :upsert)
      define(:get_subscription_by_stripe_id, action: :read, get_by: [:stripe_subscription_id])
    end

    resource Stellar.Payments.WebhookEvent do
      define(:record_webhook_event, action: :create)
      define(:get_webhook_event_by_stripe_id, action: :read, get_by: [:stripe_event_id])
    end
  end
end
