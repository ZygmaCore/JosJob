defmodule Josjob.Repo.Migrations.AddCourseIsPublic do
  @moduledoc """
  Adds `courses.is_public` — public (visible to every student in the catalog)
  vs org-scoped (visible only to members of an org the course is shared to).

  Hand-written (native `mix ash.codegen` unavailable on Windows: xberg NIF); the
  matching resource snapshot is updated alongside so codegen sees no drift.
  """

  use Ecto.Migration

  def up do
    alter table(:courses) do
      add :is_public, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:courses) do
      remove :is_public
    end
  end
end
