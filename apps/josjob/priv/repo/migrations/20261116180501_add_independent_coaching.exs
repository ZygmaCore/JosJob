defmodule Josjob.Repo.Migrations.AddIndependentCoaching do
  use Ecto.Migration

  def change do
    create table(:coaching_profiles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :display_name, :text, null: false
      add :headline, :text, null: false
      add :bio, :text, null: false
      add :expertise, {:array, :text}, null: false, default: []
      add :session_minutes, :integer, null: false, default: 30
      add :status, :text, null: false, default: "pending"
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create unique_index(:coaching_profiles, [:user_id],
             name: :coaching_profiles_unique_coach_user_index
           )

    create constraint(:coaching_profiles, :coaching_profile_status,
             check: "status IN ('pending','approved','suspended')"
           )

    create constraint(:coaching_profiles, :coaching_duration,
             check: "session_minutes BETWEEN 15 AND 120"
           )

    create table(:coaching_slots, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :coach_id, references(:coaching_profiles, type: :uuid, on_delete: :delete_all),
        null: false

      add :starts_at, :utc_datetime_usec, null: false
      add :ends_at, :utc_datetime_usec, null: false
      add :enabled, :boolean, null: false, default: true
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create unique_index(:coaching_slots, [:coach_id, :starts_at],
             name: :coaching_slots_unique_coach_start_index
           )

    create constraint(:coaching_slots, :coaching_slot_time, check: "ends_at > starts_at")

    create table(:coaching_bookings, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :coach_id, references(:coaching_profiles, type: :uuid, on_delete: :delete_all),
        null: false

      add :slot_id, references(:coaching_slots, type: :uuid, on_delete: :delete_all), null: false
      add :learner_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :starts_at, :utc_datetime_usec, null: false
      add :ends_at, :utc_datetime_usec, null: false
      add :status, :text, null: false, default: "confirmed"
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create unique_index(:coaching_bookings, [:slot_id],
             where: "status = 'confirmed'",
             name: :one_confirmed_coaching_booking
           )

    create index(:coaching_bookings, [:learner_id, :starts_at])

    create constraint(:coaching_bookings, :coaching_booking_status,
             check: "status IN ('confirmed','cancelled','completed')"
           )

    create constraint(:coaching_bookings, :coaching_booking_time, check: "ends_at > starts_at")
  end
end
