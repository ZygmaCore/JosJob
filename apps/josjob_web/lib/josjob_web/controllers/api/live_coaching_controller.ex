defmodule JosjobWeb.Api.LiveCoachingController do
  use JosjobWeb, :controller

  def index(conn, _params) do
    data =
      conn.assigns.current_user
      |> JosjobLrn.Coaching.dashboard()
      |> Map.put(:live_configured, JosjobMs.Realtime.configured?())

    json(conn, %{data: data})
  end
end
