defmodule Josjob.Repo.Migrations.AddCourseAwardsAndLockedCertificateNames do
  use Ecto.Migration

  def change do
    alter table(:candidate_cv_profiles) do
      add :full_name, :text
    end

    create table(:course_awards, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :course_id, references(:courses, type: :uuid, on_delete: :nilify_all)
      add :course_title, :text, null: false
      add :skill_tags, {:array, :text}, null: false, default: []
      add :completed_at, :utc_datetime_usec, null: false
      add :recipient_name, :text
      add :name_confirmed_at, :utc_datetime_usec
    end

    create unique_index(:course_awards, [:user_id, :course_id])

    create constraint(:course_awards, :certificate_name_confirmation,
             check:
               "(recipient_name IS NULL AND name_confirmed_at IS NULL) OR (recipient_name IS NOT NULL AND length(trim(recipient_name)) BETWEEN 2 AND 120 AND name_confirmed_at IS NOT NULL)"
           )

    execute """
            INSERT INTO course_awards (id, user_id, course_id, course_title, skill_tags, completed_at)
            SELECT gen_random_uuid(), s.user_id, c.id, c.title, c.skill_tags, s.updated_at
            FROM course_studies s JOIN courses c ON c.id = s.course_id
            WHERE EXISTS (SELECT 1 FROM course_lessons l WHERE l.course_id = c.id)
              AND NOT EXISTS (SELECT 1 FROM course_lessons l WHERE l.course_id = c.id
                AND NOT (l.id = ANY(s.completed_lesson_ids)))
            ON CONFLICT (user_id, course_id) DO NOTHING
            """,
            "SELECT 1"

    execute """
            CREATE FUNCTION protect_course_award() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN
              IF OLD.name_confirmed_at IS NOT NULL AND NEW IS DISTINCT FROM OLD THEN
                RAISE EXCEPTION 'Issued certificate is immutable' USING ERRCODE = '23514';
              END IF;
              IF (NEW.user_id, NEW.course_title, NEW.skill_tags, NEW.completed_at)
                  IS DISTINCT FROM (OLD.user_id, OLD.course_title, OLD.skill_tags, OLD.completed_at) THEN
                RAISE EXCEPTION 'Course award snapshot is immutable' USING ERRCODE = '23514';
              END IF;
              RETURN NEW;
            END $$;
            """,
            "DROP FUNCTION protect_course_award()"

    execute "CREATE TRIGGER protect_course_award BEFORE UPDATE ON course_awards FOR EACH ROW EXECUTE FUNCTION protect_course_award()",
            "DROP TRIGGER protect_course_award ON course_awards"
  end
end
