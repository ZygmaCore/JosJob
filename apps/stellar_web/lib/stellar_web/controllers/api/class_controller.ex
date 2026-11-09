defmodule StellarWeb.Api.ClassController do
  @moduledoc """
  Kelas milik instructor (Bearer). Dipakai teacher untuk memilih kelas saat memulai
  sesi live per-kelas (room `class:<id>`). Hanya kelas dengan `instructor_id` == user.
  """
  use StellarWeb, :controller

  require Ash.Query

  alias StellarLrn.Learning.Class

  # GET /api/me/classes
  def index(conn, _params) do
    user = conn.assigns.current_user

    classes =
      Class
      |> Ash.Query.filter(instructor_id == ^user.id)
      |> Ash.Query.sort(title: :asc)
      |> Ash.Query.load([:course])
      |> Ash.read!(authorize?: false)

    json(conn, %{data: Enum.map(classes, &class_json/1)})
  end

  defp class_json(c) do
    %{
      id: c.id,
      title: c.title,
      course: c.course && %{id: c.course.id, title: c.course.title}
    }
  end
end
