defmodule JosjobLrn.Learning.CourseStudy do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "course_studies" do
    field :course_id, :binary_id
    field :user_id, :binary_id
    field :completed_lesson_ids, {:array, :binary_id}, default: []
    timestamps(type: :utc_datetime_usec)
  end
end
