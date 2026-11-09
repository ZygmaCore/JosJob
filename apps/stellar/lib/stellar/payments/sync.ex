defmodule Stellar.Payments.Sync do
  @moduledoc """
  Memetakan objek Stripe (map hasil decode JSON) ke resource lokal via upsert.
  Dipakai baik oleh `Stellar.Payments.Billing` (setelah panggilan API) maupun
  `Stellar.Payments.WebhookHandler` (saat menerima event).

  Semua operasi berjalan sebagai sistem (`authorize?: false`).
  """
  alias Stellar.Payments

  @doc "Upsert Payment dari objek PaymentIntent Stripe."
  def sync_payment(%{"id" => id} = payment_intent) do
    Payments.upsert_payment(
      %{
        stripe_payment_intent_id: id,
        amount: payment_intent["amount"],
        currency: payment_intent["currency"],
        status: payment_intent["status"],
        description: payment_intent["description"],
        metadata: payment_intent["metadata"] || %{},
        customer_id: resolve_customer_id(payment_intent["customer"])
      },
      authorize?: false
    )
  end

  def sync_payment(_object), do: {:error, :invalid_object}

  @doc "Upsert Subscription dari objek Subscription Stripe."
  def sync_subscription(%{"id" => id} = subscription) do
    Payments.upsert_subscription(
      %{
        stripe_subscription_id: id,
        status: subscription["status"],
        stripe_price_id: first_price_id(subscription),
        current_period_end: unix_to_datetime(subscription["current_period_end"]),
        cancel_at_period_end: subscription["cancel_at_period_end"] || false,
        customer_id: resolve_customer_id(subscription["customer"])
      },
      authorize?: false
    )
  end

  def sync_subscription(_object), do: {:error, :invalid_object}

  @doc "Upsert Product dari objek Product Stripe."
  def sync_product(%{"id" => id} = product) do
    Payments.upsert_product(
      %{
        stripe_product_id: id,
        name: product["name"],
        description: product["description"],
        active: Map.get(product, "active", true)
      },
      authorize?: false
    )
  end

  def sync_product(_object), do: {:error, :invalid_object}

  @doc "Upsert Price dari objek Price Stripe."
  def sync_price(%{"id" => id} = price) do
    Payments.upsert_price(
      %{
        stripe_price_id: id,
        unit_amount: price["unit_amount"],
        currency: price["currency"],
        recurring_interval: get_in(price, ["recurring", "interval"]),
        active: Map.get(price, "active", true)
      },
      authorize?: false
    )
  end

  def sync_price(_object), do: {:error, :invalid_object}

  @doc "Resolusi id Customer lokal dari stripe customer id (string); nil bila tak ada."
  def resolve_customer_id(nil), do: nil

  def resolve_customer_id(stripe_customer_id) when is_binary(stripe_customer_id) do
    case Payments.get_customer_by_stripe_id(stripe_customer_id, authorize?: false) do
      {:ok, %{id: id}} -> id
      _ -> nil
    end
  end

  def resolve_customer_id(_other), do: nil

  defp first_price_id(%{"items" => %{"data" => [%{"price" => %{"id" => id}} | _]}}), do: id
  defp first_price_id(_subscription), do: nil

  defp unix_to_datetime(seconds) when is_integer(seconds), do: DateTime.from_unix!(seconds)
  defp unix_to_datetime(_other), do: nil
end
