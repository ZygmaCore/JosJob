defmodule Josjob.Payments.Stripe.Client do
  @moduledoc """
  Klien tipis Stripe REST API di atas `Req`. Kredensial dibaca dari config
  `:josjob, Josjob.Payments.Stripe` (di-set dari envs/.env di runtime.exs):

      config :josjob, Josjob.Payments.Stripe,
        secret_key: "sk_...",
        publishable_key: "pk_...",
        webhook_secret: "whsec_...",
        api_base: "https://api.stripe.com"

  Semua fungsi mengembalikan `{:ok, body_map}` untuk status 2xx, atau
  `{:error, reason}`. Body Stripe berupa form-encoded (bracket notation), lihat
  `Josjob.Payments.Stripe.FormEncoder`.
  """
  alias Josjob.Payments.Stripe.FormEncoder

  @default_base "https://api.stripe.com"
  # Pin versi API Stripe agar bentuk payload stabil lintas waktu.
  @api_version "2024-06-20"

  @type result :: {:ok, map()} | {:error, term()}

  @spec create_customer(map()) :: result()
  def create_customer(params), do: post("/v1/customers", params)

  @spec create_payment_intent(map()) :: result()
  def create_payment_intent(params), do: post("/v1/payment_intents", params)

  @spec retrieve_payment_intent(String.t()) :: result()
  def retrieve_payment_intent(id), do: request(:get, "/v1/payment_intents/#{id}", nil)

  @spec create_checkout_session(map()) :: result()
  def create_checkout_session(params), do: post("/v1/checkout/sessions", params)

  @spec create_subscription(map()) :: result()
  def create_subscription(params), do: post("/v1/subscriptions", params)

  @spec cancel_subscription(String.t()) :: result()
  def cancel_subscription(subscription_id) do
    request(:delete, "/v1/subscriptions/#{subscription_id}", nil)
  end

  @spec post(String.t(), map()) :: result()
  def post(path, params), do: request(:post, path, params)

  @doc "Publishable key untuk inisialisasi Stripe.js/Elements di klien."
  def publishable_key, do: cfg()[:publishable_key]

  @doc "Secret webhook untuk verifikasi signature."
  def webhook_secret, do: cfg()[:webhook_secret]

  defp request(method, path, params) do
    case cfg()[:secret_key] do
      key when is_binary(key) and key != "" ->
        do_request(method, path, params, key)

      _ ->
        {:error, :missing_stripe_secret_key}
    end
  end

  defp do_request(method, path, params, key) do
    req =
      Req.new(
        base_url: base_url(),
        auth: {:bearer, key},
        headers: [{"stripe-version", @api_version}],
        receive_timeout: 30_000,
        # Tanpa idempotency key -> jangan retry POST otomatis (hindari dobel charge).
        retry: false
      )

    options = [method: method, url: path] ++ request_body(params)

    case Req.request(req, options) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:stripe_error, status, body}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp request_body(params) when is_map(params) and map_size(params) > 0 do
    body = params |> FormEncoder.encode() |> URI.encode_query()
    [body: body, headers: [{"content-type", "application/x-www-form-urlencoded"}]]
  end

  defp request_body(_params), do: []

  defp base_url, do: cfg()[:api_base] || @default_base
  defp cfg, do: Application.get_env(:josjob, Josjob.Payments.Stripe, [])
end
