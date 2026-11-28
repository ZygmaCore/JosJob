defmodule Josjob.Repo.Migrations.AddReviewedCandidateCvFacts do
  use Ecto.Migration

  def up do
    alter table(:candidate_cv_profiles) do
      add :cv_facts, :map
    end

    execute """
    INSERT INTO candidate_cv_profiles (user_id, cv_facts, created_at, updated_at)
    SELECT user_id, payload || jsonb_build_object('cv_id', cv_id), now(), now()
    FROM (
      SELECT DISTINCT ON (user_id) user_id, cv_id, payload
      FROM rag_cv_analyses ORDER BY user_id, updated_at DESC, id DESC
    ) latest
    ON CONFLICT (user_id) DO UPDATE SET cv_facts = EXCLUDED.cv_facts
    WHERE candidate_cv_profiles.cv_facts IS NULL
    """
  end

  def down do
    alter table(:candidate_cv_profiles) do
      remove :cv_facts
    end
  end
end
