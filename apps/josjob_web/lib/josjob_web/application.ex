defmodule JosjobWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Presence peserta sesi live streaming (butuh Josjob.PubSub yang sudah
      # dijalankan oleh :josjob sebelum supervisor ini boot).
      JosjobWeb.Presence,
      # Start a worker by calling: JosjobWeb.Worker.start_link(arg)
      # {JosjobWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      JosjobWeb.Telemetry,
      JosjobWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JosjobWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JosjobWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
