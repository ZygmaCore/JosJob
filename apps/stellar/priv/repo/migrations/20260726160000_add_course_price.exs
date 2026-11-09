defmodule Stellar.Repo.Migrations.AddCoursePrice do
  @moduledoc """
  Adds course pricing: `courses.price_cents` (smallest currency unit; NULL/0 =
  free) and `courses.currency` (default 'usd'). Enables Stripe-gated enrolment.

  Hand-written (native `mix ash.codegen` unavailable on Windows: xberg NIF); the
  matching resource snapshot is updated alongside so codegen sees no drift.
  """

  use Ecto.Migration

  def up do
    alter table(:courses) do
      add :price_cents, :bigint
      add :currency, :text, null: false, default: "usd"
    end
  end

  def down do
    alter table(:courses) do
      remove :currency
      remove :price_cents
    end
  end
end
