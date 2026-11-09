defmodule Stellar.Payments.Billing do
  @moduledoc """
  API publik domain pembayaran — dipanggil dari controller web.

  Menggabungkan panggilan Stripe (`Stripe.Client`), persistensi lokal (`Sync`),
  dan verifikasi webhook (`Stripe.Webhook`). Argumen `user` cukup map/struct
  dengan field `:id` dan `:email` (mis. `Stellar.Accounts.User`).
  """
  alias Stellar.Payments
  alias Stellar.Payments.{Sync, WebhookHandler}
  alias Stellar.Payments.Stripe.{Client, Webhook}

  @doc """
  Pastikan `user` punya Customer Stripe. Kembalikan yang tersimpan; bila belum
  ada, buat di Stripe lalu simpan lokal.
  """
  def ensure_customer(%{id: user_id, email: email}) do
    # `email` may be an Ash.CiString (case-insensitive type) — the Stripe form
    # encoder only handles plain scalars, so normalise to a String first.
    email = to_string(email)

    case Payments.get_customer_by_user(user_id, authorize?: false) do
      {:ok, %Payments.Customer{} = customer} ->
        {:ok, customer}

      _ ->
        with {:ok, stripe_customer} <-
               Client.create_customer(%{
                 "email" => email,
                 "metadata" => %{"user_id" => user_id}
               }),
             {:ok, customer} <-
               Payments.upsert_customer(
                 %{stripe_customer_id: stripe_customer["id"], user_id: user_id, email: email},
                 authorize?: false
               ) do
          {:ok, customer}
        end
    end
  end

  @doc """
  Buat PaymentIntent (sekali bayar) untuk `user`. `opts` = `%{amount:, currency:,
  description:}` (`amount` satuan terkecil). Mengembalikan `client_secret` untuk
  dikonfirmasi klien via Stripe Elements.
  """
  def create_payment_intent(user, %{amount: amount, currency: currency} = opts) do
    with {:ok, customer} <- ensure_customer(user),
         {:ok, payment_intent} <-
           Client.create_payment_intent(%{
             "amount" => amount,
             "currency" => currency,
             "customer" => customer.stripe_customer_id,
             "description" => opts[:description],
             "automatic_payment_methods" => %{"enabled" => true},
             # Caller can stash purchase context (e.g. class_id) so a webhook /
             # server confirm can fulfil the right enrolment; user_id always set.
             "metadata" => Map.merge(%{"user_id" => user.id}, opts[:metadata] || %{})
           }),
         {:ok, payment} <- Sync.sync_payment(payment_intent) do
      {:ok,
       %{
         payment: payment,
         payment_intent_id: payment_intent["id"],
         client_secret: payment_intent["client_secret"]
       }}
    end
  end

  @doc """
  Buat Checkout Session. `params` = `%{mode:, line_items:, success_url:,
  cancel_url:}` dengan `mode` "payment" (sekali bayar) atau "subscription".
  Mengembalikan objek session Stripe (punya `"id"` & `"url"`).
  """
  def create_checkout_session(user, params) do
    with {:ok, customer} <- ensure_customer(user) do
      Client.create_checkout_session(%{
        "mode" => params.mode,
        "customer" => customer.stripe_customer_id,
        "line_items" => params.line_items,
        "success_url" => params.success_url,
        "cancel_url" => params.cancel_url
      })
    end
  end

  @doc """
  Buat langganan untuk `user` pada `price_id`. Memakai
  `payment_behavior: default_incomplete` sehingga mengembalikan `client_secret`
  invoice pertama untuk dikonfirmasi klien.
  """
  def create_subscription(user, price_id) when is_binary(price_id) do
    with {:ok, customer} <- ensure_customer(user),
         {:ok, subscription} <-
           Client.create_subscription(%{
             "customer" => customer.stripe_customer_id,
             "items" => [%{"price" => price_id}],
             "payment_behavior" => "default_incomplete",
             "payment_settings" => %{"save_default_payment_method" => "on_subscription"},
             "expand" => ["latest_invoice.payment_intent"]
           }),
         {:ok, local} <- Sync.sync_subscription(subscription) do
      {:ok, %{subscription: local, client_secret: subscription_client_secret(subscription)}}
    end
  end

  @doc "Ambil PaymentIntent dari Stripe untuk verifikasi status di server."
  def get_payment_intent(payment_intent_id) when is_binary(payment_intent_id),
    do: Client.retrieve_payment_intent(payment_intent_id)

  @doc "Batalkan langganan (segera) di Stripe lalu sinkron lokal."
  def cancel_subscription(stripe_subscription_id) when is_binary(stripe_subscription_id) do
    with {:ok, subscription} <- Client.cancel_subscription(stripe_subscription_id),
         {:ok, local} <- Sync.sync_subscription(subscription) do
      {:ok, local}
    end
  end

  @doc """
  Verifikasi payload webhook (signature) lalu proses secara idempoten.
  `secret` default dari config; dapat dioverride (mis. untuk test).
  """
  def handle_webhook(payload, signature_header, secret \\ Client.webhook_secret()) do
    with {:ok, event} <- Webhook.construct_event(payload, signature_header, secret),
         {:ok, _result} <- WebhookHandler.process(event) do
      # Return the verified event so the web layer can run cross-domain
      # fulfilment (e.g. create an Enrollment) that this payments-only domain
      # must not reference directly (umbrella dependency direction).
      {:ok, event}
    end
  end

  defp subscription_client_secret(%{
         "latest_invoice" => %{"payment_intent" => %{"client_secret" => secret}}
       }),
       do: secret

  defp subscription_client_secret(_subscription), do: nil
end
