defmodule Josjob.Repo.Migrations.AddJobApplicationsAndChat do
  use Ecto.Migration

  def change do
    create table(:job_applications, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :job_id, references(:jobs, type: :uuid, on_delete: :restrict), null: false
      add :candidate_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :status, :text, null: false, default: "applied"
      add :cover_letter, :text, null: false, default: ""
      add :profile_snapshot, :map, null: false
      add :interview_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:job_applications, [:job_id, :candidate_id])
    create index(:job_applications, [:candidate_id, :inserted_at])

    create constraint(:job_applications, :application_status,
             check:
               "status IN ('applied','reviewing','interview','offer','hired','rejected','withdrawn')"
           )

    create table(:job_application_events, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :application_id, references(:job_applications, type: :uuid, on_delete: :delete_all),
        null: false

      add :actor_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :status, :text, null: false
      add :note, :text, null: false, default: ""
      add :scheduled_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:job_application_events, [:application_id, :inserted_at])

    create table(:chat_messages) do
      add :application_id, references(:job_applications, type: :uuid, on_delete: :delete_all)
      add :booking_id, references(:coaching_bookings, type: :uuid, on_delete: :delete_all)
      add :sender_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :client_id, :text, null: false
      add :body, :text, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(:chat_messages, :one_chat_context,
             check:
               "(application_id IS NOT NULL)::integer + (booking_id IS NOT NULL)::integer = 1"
           )

    create constraint(:chat_messages, :message_body_length,
             check: "char_length(body) BETWEEN 1 AND 4000"
           )

    create unique_index(:chat_messages, [:sender_id, :client_id])
    create index(:chat_messages, [:application_id, :id])
    create index(:chat_messages, [:booking_id, :id])
  end
end
