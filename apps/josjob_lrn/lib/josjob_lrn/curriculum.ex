defmodule JosjobLrn.Curriculum do
  @moduledoc "Self-paced course access, ordered lessons and private, server-graded progress."
  import Ecto.Query
  require Ash.Query
  alias Josjob.Repo
  alias JosjobLrn.Learning.{Course, CourseLesson, CourseStudy, Enrollment}

  def lessons(id),
    do: Repo.all(from l in CourseLesson, where: l.course_id == ^id, order_by: l.position)

  def published?(id), do: Repo.exists?(from l in CourseLesson, where: l.course_id == ^id)

  def get(user, id) do
    with {:ok, course} <- visible_course(user, id) do
      enrollment = study(user.id, id)

      if enrollment && course.price_cents && course.price_cents > 0 && !paid_access?(user, id),
        do: {:error, :payment_required},
        else: {:ok, serialize(course, lessons(id), enrollment)}
    end
  end

  def enroll(user, id) do
    with {:ok, course} <- visible_course(user, id),
         true <- published?(id) || {:error, :curriculum_unavailable},
         true <- is_nil(course.price_cents) or course.price_cents <= 0 or paid_access?(user, id) do
      Repo.insert!(%CourseStudy{user_id: user.id, course_id: id},
        on_conflict: :nothing,
        conflict_target: [:user_id, :course_id]
      )

      get(user, id)
    else
      false -> {:error, :payment_required}
      error -> error
    end
  end

  def complete(user, id, lesson_id, answers) do
    with {:ok, course} <- visible_course(user, id),
         {:ok, _} <- get(user, id),
         %CourseStudy{} = enrollment <- study(user.id, id) do
      Repo.transaction(fn ->
        enrollment =
          Repo.one!(from s in CourseStudy, where: s.id == ^enrollment.id, lock: "FOR UPDATE")

        lessons = lessons(id)
        lesson = Enum.find(lessons, &(&1.id == lesson_id)) || Repo.rollback(:not_found)
        done = enrollment.completed_lesson_ids
        previous = Enum.take_while(lessons, &(&1.id != lesson.id))
        if Enum.any?(previous, &(&1.id not in done)), do: Repo.rollback(:lesson_locked)

        {passed, score} = grade(lesson, answers)

        if lesson.id not in done and passed do
          enrollment
          |> Ecto.Changeset.change(completed_lesson_ids: done ++ [lesson.id])
          |> Repo.update!()
        end

        updated = study(user.id, id)

        if lessons != [] and Enum.all?(lessons, &(&1.id in updated.completed_lesson_ids)),
          do: JosjobLrn.CourseAwards.ensure(user, course)

        serialize(course, lessons, updated)
        |> Map.put(:assessment, %{passed: passed, score: score})
      end)
    else
      nil -> {:error, :enrollment_required}
      error -> error
    end
  end

  def mine(user) do
    Repo.all(from s in CourseStudy, where: s.user_id == ^user.id, order_by: [desc: s.updated_at])
    |> Enum.flat_map(fn s ->
      case get(user, s.course_id) do
        {:ok, course} ->
          [Map.take(course, [:id, :title, :progress, :completed_count, :lesson_count])]

        _ ->
          []
      end
    end)
  end

  defp study(user_id, course_id),
    do: Repo.get_by(CourseStudy, user_id: user_id, course_id: course_id)

  defp visible_course(user, id) do
    with {:ok, _} <- Ecto.UUID.cast(id) do
      org_ids = user |> Josjob.Authz.member_orgs() |> Enum.map(& &1.id)

      case Course
           |> Ash.Query.filter(
             id == ^id and is_active == true and
               (is_public == true or organizations.id in ^org_ids)
           )
           |> Ash.read_one(authorize?: false) do
        {:ok, nil} -> {:error, :not_found}
        result -> result
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp paid_access?(user, id) do
    Enrollment
    |> Ash.Query.filter(student_id == ^user.id and class.course_id == ^id)
    |> Ash.exists?(authorize?: false)
  end

  defp grade(%{kind: "reading"}, _answers), do: {true, nil}

  defp grade(%{questions: questions}, answers) when is_map(answers) and questions != [] do
    correct =
      Enum.count(questions, fn q ->
        is_integer(answers[q["id"]]) and answers[q["id"]] == q["correct_index"]
      end)

    score = round(correct * 100 / length(questions))
    {score >= 80, score}
  end

  defp grade(_, _), do: {false, 0}

  defp serialize(course, lessons, enrollment) do
    done = if enrollment, do: enrollment.completed_lesson_ids, else: []
    completed_count = Enum.count(lessons, &(&1.id in done))
    lesson_count = length(lessons)
    first_open = Enum.find(lessons, &(&1.id not in done))

    %{
      id: course.id,
      title: course.title,
      skill_tags: course.skill_tags,
      enrolled: not is_nil(enrollment),
      lesson_count: lesson_count,
      completed_count: completed_count,
      progress: if(lesson_count == 0, do: 0, else: round(100 * completed_count / lesson_count)),
      award:
        if(enrollment,
          do:
            JosjobLrn.CourseAwards.for_course(enrollment.user_id, course.id)
            |> JosjobLrn.CourseAwards.json(),
          else: nil
        ),
      resume_lesson_id: first_open && first_open.id,
      lessons:
        Enum.map(lessons, fn lesson ->
          unlocked =
            enrollment != nil and
              (lesson.id in done or first_open == nil or lesson.position <= first_open.position)

          %{
            id: lesson.id,
            title: lesson.title,
            module_title: lesson.module_title,
            kind: lesson.kind,
            position: lesson.position,
            completed: lesson.id in done,
            unlocked: unlocked,
            body: if(unlocked, do: lesson.body, else: nil),
            questions:
              if(unlocked,
                do: Enum.map(lesson.questions, &Map.take(&1, ["id", "prompt", "options"])),
                else: []
              )
          }
        end)
    }
  end
end
