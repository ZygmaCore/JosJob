defmodule JosjobWeb.Api.CurriculumController do
  use JosjobWeb, :controller
  alias JosjobLrn.Curriculum
  def show(conn, %{"id" => id}), do: respond(conn, Curriculum.get(conn.assigns.current_user, id))

  def enroll(conn, %{"id" => id}),
    do: respond(conn, Curriculum.enroll(conn.assigns.current_user, id))

  def complete(conn, %{"id" => id, "lesson_id" => lesson_id} = params),
    do:
      respond(
        conn,
        Curriculum.complete(conn.assigns.current_user, id, lesson_id, params["answers"])
      )

  def index(conn, _), do: json(conn, %{data: Curriculum.mine(conn.assigns.current_user)})
  defp respond(conn, {:ok, data}), do: json(conn, %{data: data})

  defp respond(conn, {:error, reason}) do
    status =
      case reason do
        :not_found -> 404
        :payment_required -> 402
        :enrollment_required -> 403
        :lesson_locked -> 409
        :curriculum_unavailable -> 409
        _ -> 422
      end

    conn |> put_status(status) |> json(%{error: to_string(reason)})
  end
end
