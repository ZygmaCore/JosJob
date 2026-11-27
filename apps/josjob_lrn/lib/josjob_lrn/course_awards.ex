defmodule JosjobLrn.CourseAwards do
  @moduledoc "Course skill grants and once-only, CV-confirmed certificate names."
  import Ecto.Query
  alias Josjob.Repo
  alias Josjob.Accounts.User
  alias JosjobJob.{CourseAward, CurriculumVitae}

  def ensure(user, course) do
    Repo.insert!(
      %CourseAward{
        user_id: user.id,
        course_id: course.id,
        course_title: course.title,
        skill_tags: Enum.uniq_by(course.skill_tags, &String.downcase/1),
        completed_at: DateTime.utc_now()
      }, on_conflict: :nothing, conflict_target: [:user_id, :course_id])
  end

  def for_course(user_id, course_id),
    do: Repo.get_by(CourseAward, user_id: user_id, course_id: course_id)

  def list(user),
    do:
      Repo.all(
        from a in CourseAward, where: a.user_id == ^user.id, order_by: [desc: a.completed_at]
      )

  def preview(user, id) do
    with {:ok, award} <- owned(user, id) do
      {:ok, json(award) |> Map.put(:cv_name, cv_name(user))}
    end
  end

  def confirm(user, id, params) do
    with {:ok, _} <- owned(user, id) do
      Repo.transaction(fn ->
        Repo.query!("SELECT id FROM users WHERE id::text = $1 FOR UPDATE", [user.id])

        award =
          Repo.one!(
            from a in CourseAward,
              where: a.id == ^id and a.user_id == ^user.id,
              lock: "FOR UPDATE"
          )

        if award.name_confirmed_at do
          json(award)
        else
          if params["confirm_cv"] != true, do: Repo.rollback(:cv_confirmation_required)
          fresh_user = Ash.get!(User, user.id, authorize?: false)
          name = cv_name(fresh_user)

          if not is_binary(name) or String.length(String.trim(name)) < 2 or
               String.length(name) > 120,
             do: Repo.rollback(:cv_name_required)

          if params["expected_name"] != name, do: Repo.rollback(:cv_name_changed)

          award
          |> Ecto.Changeset.change(recipient_name: name, name_confirmed_at: DateTime.utc_now())
          |> Repo.update!()
          |> json()
        end
      end)
    end
  end

  def owned(user, id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %CourseAward{} = award <- Repo.get_by(CourseAward, id: id, user_id: user.id) do
      {:ok, award}
    else
      _ -> {:error, :not_found}
    end
  end

  defp cv_name(user), do: CurriculumVitae.get_for(user).identity.full_name

  def json(nil), do: nil

  def json(award) do
    %{
      id: award.id,
      course_id: award.course_id,
      title: award.course_title,
      issuer: "JosJob",
      skill_tags: award.skill_tags,
      completed_at: award.completed_at,
      recipient_name: award.recipient_name,
      name_locked: not is_nil(award.name_confirmed_at),
      issued_on: award.name_confirmed_at && DateTime.to_date(award.name_confirmed_at),
      credential_id:
        if(award.name_confirmed_at, do: "JOSJOB-" <> String.upcase(award.id), else: nil),
      source: "course_completion",
      editable: false,
      expired: false,
      expires_on: nil,
      credential_url: nil,
      recorded_period: nil
    }
  end
end
