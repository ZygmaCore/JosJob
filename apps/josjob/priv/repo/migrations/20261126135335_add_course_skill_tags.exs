defmodule Josjob.Repo.Migrations.AddCourseSkillTags do
  use Ecto.Migration

  def change do
    alter table(:courses) do
      add :skill_tags, {:array, :text}, null: false, default: []
    end
  end
end
