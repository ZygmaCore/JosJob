defmodule Josjob.Payments.Stripe.WebhookTest do
  use ExUnit.Case, async: true

  alias Josjob.Payments.Stripe.Webhook

  @secret "whsec_test_secret"
  @payload ~s({"id":"evt_123","type":"payment_intent.succeeded"})
  @timestamp 1_700_000_000

  defp sign(payload, timestamp, secret) do
    signature =
      :hmac
      |> :crypto.mac(:sha256, secret, "#{timestamp}.#{payload}")
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signature}"
  end

  test "accepts a valid signature and decodes the event" do
    header = sign(@payload, @timestamp, @secret)

    assert {:ok, %{"id" => "evt_123", "type" => "payment_intent.succeeded"}} =
             Webhook.construct_event(@payload, header, @secret, now: @timestamp)
  end

  test "rejects a tampered payload" do
    header = sign(@payload, @timestamp, @secret)
    tampered = ~s({"id":"evt_123","type":"payment_intent.payment_failed"})

    assert {:error, :signature_mismatch} =
             Webhook.construct_event(tampered, header, @secret, now: @timestamp)
  end

  test "rejects a wrong secret" do
    header = sign(@payload, @timestamp, @secret)

    assert {:error, :signature_mismatch} =
             Webhook.construct_event(@payload, header, "whsec_wrong", now: @timestamp)
  end

  test "rejects a stale timestamp beyond tolerance" do
    header = sign(@payload, @timestamp, @secret)

    assert {:error, :timestamp_out_of_tolerance} =
             Webhook.construct_event(@payload, header, @secret,
               now: @timestamp + 1000,
               tolerance: 300
             )
  end

  test "rejects a malformed header" do
    assert {:error, :invalid_signature_header} =
             Webhook.construct_event(@payload, "not-a-valid-header", @secret, now: @timestamp)
  end

  test "rejects an empty signature header" do
    assert {:error, :invalid_signature_header} =
             Webhook.construct_event(@payload, "", @secret, now: @timestamp)
  end
end
