defmodule JosjobJob.CourseAward do
  @moduledoc "Immutable earned course skills and an optionally confirmed certificate identity."
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "course_awards" do
    field(:user_id, :binary_id)
    field(:course_id, :binary_id)
    field(:course_title, :string)
    field(:skill_tags, {:array, :string}, default: [])
    field(:completed_at, :utc_datetime_usec)
    field(:recipient_name, :string)
    field(:name_confirmed_at, :utc_datetime_usec)
  end
end
