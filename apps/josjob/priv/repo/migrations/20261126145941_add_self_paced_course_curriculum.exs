defmodule Josjob.Repo.Migrations.AddSelfPacedCourseCurriculum do
  use Ecto.Migration

  def change do
    create table(:course_lessons, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :course_id, references(:courses, type: :uuid, on_delete: :delete_all), null: false
      add :module_title, :text, null: false
      add :title, :text, null: false
      add :position, :integer, null: false
      add :kind, :text, null: false, default: "reading"
      add :body, :text, null: false, default: ""
      add :questions, {:array, :map}, null: false, default: []
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:course_lessons, [:course_id, :position])
    create constraint(:course_lessons, :course_lessons_kind, check: "kind IN ('reading', 'quiz')")

    create table(:course_studies, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :course_id, references(:courses, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :completed_lesson_ids, {:array, :uuid}, null: false, default: []
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:course_studies, [:user_id, :course_id])
  end
end
