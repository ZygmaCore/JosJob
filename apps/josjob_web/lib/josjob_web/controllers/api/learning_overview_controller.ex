defmodule JosjobWeb.Api.LearningOverviewController do
  use JosjobWeb, :controller

  def show(conn, params) do
    case JosjobLrn.Overview.fetch(conn.assigns.current_user, Map.get(params, "scope", "learner")) do
      {:ok, overview} ->
        json(conn, %{data: overview})

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      {:error, :invalid_scope} ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_scope"})
    end
  end
end
