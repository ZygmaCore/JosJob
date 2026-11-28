defmodule Josjob.Payments.WebhookEvent do
  @moduledoc """
  Log event webhook Stripe untuk idempotensi. Kunci unik `stripe_event_id`
  memastikan tiap event hanya diproses sekali (Stripe dapat mengirim ulang event
  yang sama). Lihat `Josjob.Payments.WebhookHandler`.
  """
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Payments

  postgres do
    table("payment_webhook_events")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:stripe_event_id, :string, allow_nil?: false, public?: true)
    attribute(:type, :string, public?: true)
    attribute(:payload, :map, default: %{}, public?: true)

    attribute(:status, :atom,
      constraints: [one_of: [:received, :processed, :failed]],
      default: :received,
      public?: true
    )

    attribute(:processed_at, :utc_datetime, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_stripe_event_id, [:stripe_event_id])
  end

  actions do
    default_accept([:stripe_event_id, :type, :payload, :status])
    defaults([:create, :read, :update, :destroy])

    update :mark_processed do
      accept([])
      # `processed_at` diisi via change berbasis fungsi (waktu sekarang) sehingga
      # tak bisa dilakukan atomik sebagai satu UPDATE SQL. Aman non-atomik karena
      # hanya menandai satu baris event (by id).
      require_atomic?(false)
      change(set_attribute(:status, :processed))

      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :processed_at,
          DateTime.truncate(DateTime.utc_now(), :second)
        )
      end)
    end

    update :mark_failed do
      accept([])
      change(set_attribute(:status, :failed))
    end
  end
end
