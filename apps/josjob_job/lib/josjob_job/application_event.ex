defmodule JosjobJob.ApplicationEvent do
  @moduledoc "Append-only history visible to both the applicant and the hiring team."
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "job_application_events" do
    field(:application_id, :binary_id)
    field(:actor_id, :binary_id)
    field(:status, :string)
    field(:note, :string, default: "")
    field(:scheduled_at, :utc_datetime_usec)
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
