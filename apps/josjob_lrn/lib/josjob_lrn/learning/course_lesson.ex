defmodule JosjobLrn.Learning.CourseLesson do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "course_lessons" do
    field :course_id, :binary_id
    field :module_title, :string
    field :title, :string
    field :position, :integer
    field :kind, :string, default: "reading"
    field :body, :string, default: ""
    field :questions, {:array, :map}, default: []
    timestamps(type: :utc_datetime_usec)
  end
end
