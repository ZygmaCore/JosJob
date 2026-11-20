defmodule JosjobWeb.Api.CoachingController do
  use JosjobWeb, :controller
  alias JosjobLrn.Coaching

  def save_profile(conn, params),
    do: mutate(conn, fn -> Coaching.save_profile(conn.assigns.current_user, params) end)

  def create_slot(conn, params),
    do: mutate(conn, fn -> Coaching.create_slot(conn.assigns.current_user, params) end)

  def close_slot(conn, %{"id" => id}),
    do: mutate(conn, fn -> Coaching.close_slot(conn.assigns.current_user, id) end)

  def book(conn, %{"slot_id" => id}),
    do: mutate(conn, fn -> Coaching.book(conn.assigns.current_user, id) end)

  def book(conn, _params), do: conn |> put_status(400) |> json(%{error: "slot_id_required"})

  def update_booking(conn, %{"id" => id, "action" => action}),
    do: mutate(conn, fn -> Coaching.change_booking(conn.assigns.current_user, id, action) end)

  def update_booking(conn, _params),
    do: conn |> put_status(400) |> json(%{error: "action_required"})

  def review(conn, %{"id" => id, "status" => status}),
    do: mutate(conn, fn -> Coaching.review(conn.assigns.current_user, id, status) end)

  def review(conn, _params), do: conn |> put_status(400) |> json(%{error: "status_required"})

  def admin_profiles(conn, _params) do
    case Coaching.admin_profiles(conn.assigns.current_user) do
      {:ok, profiles} -> json(conn, %{data: Enum.map(profiles, &Coaching.profile_json/1)})
      error -> respond(conn, error)
    end
  end

  defp mutate(conn, fun) do
    case fun.() do
      {:ok, _} -> json(conn, %{ok: true})
      error -> respond(conn, error)
    end
  rescue
    error in Ash.Error.Invalid -> respond(conn, {:error, error})
  end

  defp respond(conn, {:error, %Ash.Error.Invalid{} = error}) do
    fields = Enum.map(error.errors, &Exception.message/1)
    conn |> put_status(422) |> json(%{error: "validation_failed", details: fields})
  end

  defp respond(conn, {:error, reason}) when is_atom(reason) do
    status =
      case reason do
        :not_found -> 404
        :forbidden -> 403
        reason when reason in [:slot_unavailable, :overlap, :self_booking, :invalid_status] -> 409
        _ -> 400
      end

    conn |> put_status(status) |> json(%{error: reason})
  end
end
