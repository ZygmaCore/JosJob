defmodule JosjobWeb.Enrollments do
  @moduledoc """
  Cross-domain enrolment fulfilment. Lives in `:josjob_web` (which depends on
  BOTH `:josjob_lrn` and `:josjob`) so it may create a `JosjobLrn.Learning`
  enrolment after a `Josjob.Payments` charge succeeds — a link the payments
  domain itself must not make (umbrella dependency direction).

  Idempotent: an already-enrolled (class, student) returns the existing row, so
  the synchronous confirm path and the webhook backstop can both call it safely.
  """
  require Ash.Query

  alias JosjobLrn.Learning.Enrollment

  @doc """
  Ensure `user_id` is enrolled in `class_id`. Returns `{:ok, enrollment}` (new
  or pre-existing) or `{:error, reason}` (`:full` when capacity is exhausted).
  """
  def fulfill(class_id, user_id) when is_binary(class_id) and is_binary(user_id) do
    case existing(class_id, user_id) do
      %Enrollment{} = enr ->
        {:ok, enr}

      nil ->
        Enrollment
        |> Ash.Changeset.for_create(:create, %{class_id: class_id, student_id: user_id})
        |> Ash.create(authorize?: false)
    end
  end

  def fulfill(_class_id, _user_id), do: {:error, :invalid}

  @doc "Whether `user_id` already has an enrolment in `class_id`."
  def enrolled?(class_id, user_id), do: not is_nil(existing(class_id, user_id))

  defp existing(class_id, user_id) do
    Enrollment
    |> Ash.Query.filter(class_id == ^class_id and student_id == ^user_id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end
end
