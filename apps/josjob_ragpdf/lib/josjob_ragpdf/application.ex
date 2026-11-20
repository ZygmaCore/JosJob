defmodule JosjobRagpdf.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JosjobRagpdf.Jobs,
      {Task.Supervisor, name: JosjobRagpdf.TaskSupervisor},
      JosjobRagpdf.Queue
    ]

    children =
      if Application.get_env(:josjob_ragpdf, :start_server, true) do
        port = Application.get_env(:josjob_ragpdf, :port, 4010)

        children ++
          [
            {Bandit, plug: JosjobRagpdfWeb.Router, port: port, ip: {0, 0, 0, 0}}
          ]
      else
        children
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: JosjobRagpdf.Supervisor)
  end
end
