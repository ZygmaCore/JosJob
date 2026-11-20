defmodule JosjobRagpdfWeb.Router do
  @moduledoc """
  Minimal Bandit + `Plug.Router` HTTP surface.

  Keep this dumb: validate, enqueue, and read the ETS store. No LLM call ever
  happens inside a request.
  """

  use Plug.Router
  use Plug.ErrorHandler

  require Logger

  alias JosjobRagpdfWeb.Controllers.{AnalysisController, HealthController}

  plug Plug.RequestId
  plug Plug.Logger
  plug :match
  plug JosjobRagpdfWeb.Plugs.Auth
  plug JosjobRagpdfWeb.Plugs.BodyParser
  plug :dispatch

  get "/health" do
    HealthController.health(conn)
  end

  get "/" do
    HealthController.index(conn)
  end

  get "/v1/queue" do
    HealthController.queue(conn)
  end

  post "/v1/cv/analyses" do
    AnalysisController.create(conn)
  end

  get "/v1/cv/analyses/:id" do
    AnalysisController.show(conn)
  end

  delete "/v1/cv/analyses/:id" do
    AnalysisController.delete(conn)
  end

  match _ do
    JosjobRagpdfWeb.JSON.not_found(conn, "endpoint not found")
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{kind: kind, reason: reason}) do
    Logger.error("josjob_ragpdf request failed: #{inspect(kind)} #{inspect(reason)}")

    status = error_status(reason)

    if conn.state in [:sent, :chunked, :file, :upgraded] do
      conn
    else
      message = if status == 500, do: "internal server error", else: "request could not be parsed"
      error = if status == 500, do: "internal_error", else: "bad_request"
      JosjobRagpdfWeb.JSON.send_error(conn, status, error, message)
    end
  end

  defp error_status(%{__exception__: true} = exception) do
    Plug.Exception.status(exception)
  rescue
    _ -> 500
  end

  defp error_status(_reason), do: 500
end
