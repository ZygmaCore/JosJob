defmodule Josjob.Payments.WebhookHandler do
  @moduledoc """
  Memproses event webhook Stripe secara idempoten.

  Tiap event dicatat di `WebhookEvent` (kunci unik `stripe_event_id`). Event yang
  sudah `:processed` dilewati (`{:ok, :duplicate}`). Sisanya diarahkan ke `Sync`
  sesuai prefix `type`. Event tak dikenal tetap dicatat dan dianggap sukses.
  """
  alias Josjob.Payments
  alias Josjob.Payments.Sync

  require Logger

  @spec process(map()) :: {:ok, atom()} | {:error, term()}
  def process(%{"id" => event_id, "type" => type} = event) do
    case Payments.get_webhook_event_by_stripe_id(event_id, authorize?: false) do
      {:ok, %{status: :processed}} ->
        {:ok, :duplicate}

      {:ok, %{} = record} ->
        dispatch(record, type, event)

      _ ->
        case Payments.record_webhook_event(
               %{stripe_event_id: event_id, type: type, payload: event},
               authorize?: false
             ) do
          {:ok, record} -> dispatch(record, type, event)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def process(_event), do: {:error, :invalid_event}

  defp dispatch(record, type, event) do
    object = get_in(event, ["data", "object"]) || %{}

    case handle(type, object) do
      {:ok, _result} ->
        mark(record, :mark_processed)
        {:ok, :processed}

      :ok ->
        mark(record, :mark_processed)
        {:ok, :processed}

      {:error, reason} ->
        mark(record, :mark_failed)
        Logger.warning("Gagal memproses webhook Stripe #{type}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Pembayaran sekali bayar.
  defp handle("payment_intent." <> _rest, object), do: Sync.sync_payment(object)
  # Langganan.
  defp handle("customer.subscription." <> _rest, object), do: Sync.sync_subscription(object)
  # Katalog produk/harga.
  defp handle("product." <> _rest, object), do: Sync.sync_product(object)
  defp handle("price." <> _rest, object), do: Sync.sync_price(object)
  # Event lain: cukup dicatat.
  defp handle(_type, _object), do: :ok

  defp mark(record, action) do
    record
    |> Ash.Changeset.for_update(action)
    |> Ash.update(authorize?: false)
  end
end
