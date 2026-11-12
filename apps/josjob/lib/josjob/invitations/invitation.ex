defmodule Josjob.Invitations.Invitation do
  @moduledoc """
  Undangan email → gabung organisasi dengan role sistem.

  - `email` — penerima (case-insensitive).
  - `organization_id` — org yang dipilih superuser saat mengundang.
  - `role_key` — role sistem yang diberikan saat accept (default `"teacher"`).
  - `token` — token acak URL-safe; kunci tautan accept (unik).
  - `status` — `:pending` → `:accepted` / `:revoked`.
  - `expires_at` — kedaluwarsa (default 7 hari; diperpanjang saat resend).
  - `resend_count` / `last_sent_at` — jejak pengiriman ulang.
  - `invited_by_id` / `accepted_user_id` — audit (uuid lepas, bukan FK).
  """
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Invitations

  @default_ttl_days 7

  postgres do
    table("invitations")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:role_key, :string, allow_nil?: false, default: "teacher", public?: true)
    attribute(:token, :string, allow_nil?: false, sensitive?: true)

    attribute(:status, :atom,
      constraints: [one_of: [:pending, :accepted, :revoked]],
      default: :pending,
      allow_nil?: false,
      public?: true
    )

    attribute(:expires_at, :utc_datetime, allow_nil?: false, public?: true)
    attribute(:accepted_at, :utc_datetime, public?: true)
    attribute(:last_sent_at, :utc_datetime, public?: true)
    attribute(:resend_count, :integer, allow_nil?: false, default: 0, public?: true)

    # Audit (uuid lepas — jejak tetap utuh meski user terkait kelak dihapus).
    attribute(:invited_by_id, :uuid, public?: true)
    attribute(:accepted_user_id, :uuid, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :organization, Josjob.Orgs.Organization do
      allow_nil?(false)
      attribute_writable?(true)
    end
  end

  identities do
    identity(:unique_token, [:token])
  end

  actions do
    defaults([:read, :destroy])
    default_accept([:email, :role_key, :organization_id, :invited_by_id])

    # Buat undangan: generate token acak + masa berlaku + tandai terkirim.
    create :create do
      accept([:email, :role_key, :organization_id, :invited_by_id])
      argument(:ttl_days, :integer, default: @default_ttl_days)

      change(fn changeset, _ctx ->
        ttl = Ash.Changeset.get_argument(changeset, :ttl_days) || @default_ttl_days
        now = now()

        changeset
        |> Ash.Changeset.change_attribute(:token, gen_token())
        |> Ash.Changeset.change_attribute(:status, :pending)
        |> Ash.Changeset.change_attribute(:expires_at, DateTime.add(now, ttl * 86_400, :second))
        |> Ash.Changeset.change_attribute(:last_sent_at, now)
      end)
    end

    # Kirim ulang: perpanjang masa berlaku + bump counter + stempel waktu.
    update :resend do
      require_atomic?(false)
      accept([])
      argument(:ttl_days, :integer, default: @default_ttl_days)

      change(fn changeset, _ctx ->
        ttl = Ash.Changeset.get_argument(changeset, :ttl_days) || @default_ttl_days
        now = now()
        current = changeset.data.resend_count || 0

        changeset
        |> Ash.Changeset.change_attribute(:last_sent_at, now)
        |> Ash.Changeset.change_attribute(:resend_count, current + 1)
        |> Ash.Changeset.change_attribute(:expires_at, DateTime.add(now, ttl * 86_400, :second))
        # Undangan yang sudah dibalas/dicabut tak berpindah status via resend.
        |> maybe_repending()
      end)
    end

    # Tandai diterima + catat user yang dibuat.
    update :accept do
      require_atomic?(false)
      accept([])
      argument(:user_id, :uuid, allow_nil?: false)

      change(fn changeset, _ctx ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :accepted)
        |> Ash.Changeset.change_attribute(:accepted_at, now())
        |> Ash.Changeset.change_attribute(
          :accepted_user_id,
          Ash.Changeset.get_argument(changeset, :user_id)
        )
      end)
    end

    update :revoke do
      accept([])
      change(set_attribute(:status, :revoked))
    end
  end

  # --- helpers dipakai oleh change fn di atas ---

  @doc false
  def now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  @doc false
  def gen_token, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  defp maybe_repending(changeset) do
    if changeset.data.status == :pending do
      changeset
    else
      Ash.Changeset.change_attribute(changeset, :status, :pending)
    end
  end
end
