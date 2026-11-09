# Stellar.Payments — Stripe payment gateway (core)

Ash domain (`:stellar` app) yang membungkus Stripe: pembayaran sekali bayar
(PaymentIntent/Checkout) **dan** langganan (Subscription). UI-only frontend belum
diwire ke sini; ini murni backend.

## Struktur

| Modul | Peran |
| --- | --- |
| `Stellar.Payments` | Ash domain + code interface (upsert/get). |
| `Stellar.Payments.Customer` | Map `User` ⇆ Stripe customer (`user_id` referensi lunak). |
| `Stellar.Payments.Product` / `Price` | Mirror katalog Stripe. |
| `Stellar.Payments.Payment` | Mirror PaymentIntent (sekali bayar). |
| `Stellar.Payments.Subscription` | Mirror Subscription (langganan). |
| `Stellar.Payments.WebhookEvent` | Log idempotensi event webhook. |
| `Stellar.Payments.Stripe.Client` | Klien REST tipis di atas `Req`. |
| `Stellar.Payments.Stripe.FormEncoder` | Encode param bersarang ala Stripe. |
| `Stellar.Payments.Stripe.Webhook` | Verifikasi signature `Stripe-Signature`. |
| `Stellar.Payments.Sync` | Petakan objek Stripe → upsert lokal. |
| `Stellar.Payments.WebhookHandler` | Dispatch event webhook (idempoten). |
| **`Stellar.Payments.Billing`** | **API publik** — dipanggil controller. |

Lapisan web (`:stellar_web`): `StellarWeb.Api.PaymentController`,
`StellarWeb.Api.StripeWebhookController`, plug `ApiAuth` (Bearer) & `CacheBodyReader`
(raw body untuk verifikasi webhook).

## Env vars (envs/.env — gitignored)

```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
# opsional (default https://api.stripe.com):
STRIPE_API_BASE=https://api.stripe.com
```

## Langkah setelah merge (WAJIB)

Migrasi & snapshot Ash **belum** dibuat (butuh toolchain Elixir + `mix`). Dari root
umbrella:

```bash
mix deps.get
mix ash.codegen add_payments   # generate migration + resource snapshots
mix ecto.migrate
mix compile --warnings-as-errors
mix format
mix test apps/stellar/test/stellar/payments
```

`mix ash.codegen` membuat tabel: `payment_customers`, `payment_products`,
`payment_prices`, `payments`, `payment_subscriptions`, `payment_webhook_events`.

## Endpoint HTTP

| Method | Path | Auth | Fungsi |
| --- | --- | --- | --- |
| GET | `/api/payments/config` | Bearer | publishable key |
| POST | `/api/payments/payment-intents` | Bearer | `{amount, currency?, description?}` → `client_secret` |
| POST | `/api/payments/checkout` | Bearer | `{mode, price_id, quantity?, success_url, cancel_url}` → `{id, url}` |
| POST | `/api/payments/subscriptions` | Bearer | `{price_id}` → `{subscription_id, client_secret}` |
| DELETE | `/api/payments/subscriptions/:id` | Bearer | batalkan langganan |
| POST | `/api/webhooks/stripe` | signature | terima event Stripe |

## Webhook yang ditangani

`payment_intent.*`, `customer.subscription.*`, `product.*`, `price.*`. Event lain
dicatat di `WebhookEvent` dan di-ack (200) tanpa aksi. Idempotensi via
`stripe_event_id` unik. Daftarkan endpoint di Stripe Dashboard dan set
`STRIPE_WEBHOOK_SECRET` ke signing secret endpoint tersebut.

## Catatan desain

- Resource **tanpa policy Ash**; akses dikontrol di lapisan web (`ApiAuth` untuk
  klien, `RequireAdmin` untuk `/admin`). Operasi sistem pakai `authorize?: false`.
- Belum ada idempotency-key pada POST Stripe → `Req` retry dimatikan (hindari
  dobel-charge). Tambahkan idempotency key bila ingin retry aman.
- `status` Payment/Subscription disimpan verbatim (string) agar tahan status baru.
