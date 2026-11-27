defmodule JosjobWeb.Api.CourseAwardController do
  use JosjobWeb, :controller

  def show(conn, %{"id" => id}),
    do: respond(conn, JosjobLrn.CourseAwards.preview(conn.assigns.current_user, id))

  def confirm(conn, %{"id" => id} = params),
    do: respond(conn, JosjobLrn.CourseAwards.confirm(conn.assigns.current_user, id, params))

  defp respond(conn, {:ok, data}), do: json(conn, %{data: data})

  defp respond(conn, {:error, error}) do
    status =
      case error do
        :not_found -> 404
        :cv_name_changed -> 409
        _ -> 422
      end

    conn |> put_status(status) |> json(%{error: error})
  end
end
