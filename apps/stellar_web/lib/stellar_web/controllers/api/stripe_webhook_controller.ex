defmodule StellarWeb.Api.StripeWebhookController do
  @moduledoc """
  Endpoint webhook Stripe. TANPA auth user — keaslian diverifikasi via signature
  (`Stripe-Signature`) terhadap raw body yang di-cache oleh
  `StellarWeb.Plugs.CacheBodyReader`.

  Selalu balas cepat: 200 bila diterima/diproses, 400 bila signature/verifikasi
  gagal (Stripe akan mencoba ulang untuk 4xx/5xx).
  """
  use StellarWeb, :controller

  require Logger

  alias Stellar.Payments.Billing

  def handle(conn, _params) do
    payload = raw_body(conn)
    signature = conn |> get_req_header("stripe-signature") |> List.first()

    case Billing.handle_webhook(payload, signature || "") do
      {:ok, event} ->
        # Backstop fulfilment: if a card charge for a course succeeded, ensure the
        # enrolment exists even if the client never called /confirm (async safety).
        maybe_fulfill_enrollment(event)
        send_resp(conn, 200, "")

      {:error, reason} ->
        Logger.warning("Webhook Stripe ditolak: #{inspect(reason)}")
        send_resp(conn, 400, "")
    end
  end

  # Cross-domain fulfilment lives in the web layer (StellarWeb.Enrollments), not
  # the payments domain. Best-effort: never fail the 200 ack on a fulfilment hiccup.
  defp maybe_fulfill_enrollment(%{
         "type" => "payment_intent.succeeded",
         "data" => %{"object" => %{"metadata" => %{"class_id" => cid, "user_id" => uid}}}
       })
       when is_binary(cid) and is_binary(uid) do
    StellarWeb.Enrollments.fulfill(cid, uid)
  rescue
    e -> Logger.warning("Webhook enrolment fulfilment failed: #{inspect(e)}")
  end

  defp maybe_fulfill_enrollment(_event), do: :ok

  defp raw_body(conn) do
    conn.assigns
    |> Map.get(:raw_body, [])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end
end
