defmodule JosjobRagpdfWeb.Controllers.HealthController do
  @moduledoc "Liveness, service info, and queue introspection."

  alias JosjobRagpdf.{Jobs, Queue}
  alias JosjobRagpdfWeb.JSON

  @version "0.1.0"
  @statuses ["queued", "processing", "done", "partial", "unreadable", "failed"]

  @doc "GET /health — public liveness probe."
  def health(conn) do
    data = %{
      status: "ok",
      service: "josjob_ragpdf",
      version: @version,
      queue: Queue.stats(),
      jobs: job_counts(),
      providers: providers()
    }

    JSON.send_data(conn, 200, data)
  end

  @doc "GET / — public service info."
  def index(conn) do
    data = %{
      service: "josjob_ragpdf",
      version: @version,
      description: "PDF CV extraction microservice (Gemini → 9Router → keyword)",
      endpoints: [
        "POST /v1/cv/analyses",
        "GET /v1/cv/analyses/:id",
        "DELETE /v1/cv/analyses/:id",
        "GET /v1/queue",
        "GET /health"
      ]
    }

    JSON.send_data(conn, 200, data)
  end

  @doc "GET /v1/queue — authenticated queue stats."
  def queue(conn) do
    data = %{
      queue: Queue.stats(),
      jobs: job_counts()
    }

    JSON.send_data(conn, 200, data)
  end

  defp job_counts do
    counts = Enum.frequencies_by(Jobs.all(), &Atom.to_string(&1.status))

    Map.new(@statuses, fn status -> {status, Map.get(counts, status, 0)} end)
  end

  defp providers do
    gemini = Application.get_env(:josjob_ragpdf, :gemini, [])
    nine_router = Application.get_env(:josjob_ragpdf, :nine_router, [])

    %{
      gemini: present?(gemini[:api_key]),
      nine_router: present?(nine_router[:base_url]) and present?(nine_router[:model])
    }
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
