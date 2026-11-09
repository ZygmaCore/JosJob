defmodule StellarWeb.Api.PaymentController do
  @moduledoc """
  Endpoint pembayaran untuk klien (butuh Bearer access token — lihat
  `StellarWeb.Plugs.ApiAuth`). Semua logika ada di `Stellar.Payments.Billing`.

  - `GET    /api/payments/config`          -> {publishable_key}
  - `POST   /api/payments/payment-intents` {amount, currency?, description?}
  - `POST   /api/payments/checkout`        {mode, price_id, quantity?, success_url, cancel_url}
  - `POST   /api/payments/subscriptions`   {price_id}
  - `DELETE /api/payments/subscriptions/:id`
  """
  use StellarWeb, :controller

  require Logger

  alias Stellar.Payments.Billing
  alias Stellar.Payments.Stripe.Client

  def config(conn, _params) do
    json(conn, %{publishable_key: Client.publishable_key()})
  end

  def create_payment_intent(conn, %{"amount" => amount} = params) when is_integer(amount) do
    opts = %{
      amount: amount,
      currency: params["currency"] || "usd",
      description: params["description"]
    }

    case Billing.create_payment_intent(conn.assigns.current_user, opts) do
      {:ok, result} ->
        json(conn, %{
          client_secret: result.client_secret,
          payment_intent_id: result.payment_intent_id
        })

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def create_payment_intent(conn, _params), do: bad_request(conn, "amount (integer) wajib")

  def create_checkout_session(
        conn,
        %{
          "mode" => mode,
          "price_id" => price_id,
          "success_url" => success_url,
          "cancel_url" => cancel_url
        } = params
      )
      when mode in ["payment", "subscription"] do
    checkout = %{
      mode: mode,
      line_items: [%{"price" => price_id, "quantity" => params["quantity"] || 1}],
      success_url: success_url,
      cancel_url: cancel_url
    }

    case Billing.create_checkout_session(conn.assigns.current_user, checkout) do
      {:ok, session} -> json(conn, %{id: session["id"], url: session["url"]})
      {:error, reason} -> error(conn, reason)
    end
  end

  def create_checkout_session(conn, _params) do
    bad_request(conn, "mode (payment|subscription), price_id, success_url, cancel_url wajib")
  end

  def create_subscription(conn, %{"price_id" => price_id}) when is_binary(price_id) do
    case Billing.create_subscription(conn.assigns.current_user, price_id) do
      {:ok, result} ->
        json(conn, %{
          subscription_id: result.subscription.stripe_subscription_id,
          client_secret: result.client_secret
        })

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def create_subscription(conn, _params), do: bad_request(conn, "price_id wajib")

  # :id = stripe subscription id (mis. "sub_...").
  def cancel_subscription(conn, %{"id" => id}) do
    case Billing.cancel_subscription(id) do
      {:ok, subscription} -> json(conn, %{status: subscription.status})
      {:error, reason} -> error(conn, reason)
    end
  end

  defp bad_request(conn, message) do
    conn |> put_status(:bad_request) |> json(%{error: message})
  end

  # Jangan bocorkan detail error Stripe ke klien; catat di log, balas generik.
  defp error(conn, reason) do
    Logger.warning("Payment error: #{inspect(reason)}")
    conn |> put_status(:unprocessable_entity) |> json(%{error: "payment_failed"})
  end
end
