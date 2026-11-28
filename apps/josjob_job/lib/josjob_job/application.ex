defmodule JosjobJob.Application do
  @moduledoc "A candidate's submitted profile snapshot and current hiring stage."
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "job_applications" do
    field(:job_id, :binary_id)
    field(:candidate_id, :binary_id)
    field(:status, :string, default: "applied")
    field(:cover_letter, :string, default: "")
    field(:profile_snapshot, :map)
    field(:interview_at, :utc_datetime_usec)
    field(:job_title, :string, virtual: true)
    field(:company, :string, virtual: true)
    field(:organization_id, :binary_id, virtual: true)
    field(:candidate_name, :string, virtual: true)
    timestamps(type: :utc_datetime_usec)
  end

  def submission_changeset(application, params) do
    application
    |> cast(params, [:cover_letter], empty_values: [])
    |> update_change(:cover_letter, fn value ->
      if is_binary(value), do: String.trim(value), else: value
    end)
    |> validate_length(:cover_letter, max: 4000)
    |> unique_constraint([:job_id, :candidate_id])
    |> foreign_key_constraint(:job_id)
    |> foreign_key_constraint(:candidate_id)
  end
end
