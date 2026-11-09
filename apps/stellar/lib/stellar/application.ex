defmodule Stellar.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    oban_config =
      AshOban.config(
        [Stellar.Accounts],
        repo: Stellar.Repo,
        queues: [default: 10, media_processing: 5, ai_transcription: 5, mailers: 10],
        plugins: [Oban.Plugins.Pruner]
      )

    # Honor the Oban `:testing` mode from config (test.exs sets `:manual`) so the
    # suite doesn't run the Postgres peer/stager against the Ecto sandbox pool
    # (which otherwise flakily kills connections mid-run). Only the `:testing`
    # key is merged — dev/prod queues & plugins are left untouched.
    oban_config =
      case Application.get_env(:stellar, Oban, [])[:testing] do
        nil -> oban_config
        mode -> Keyword.put(oban_config, :testing, mode)
      end

    children = [
      Stellar.Repo,
      {DNSCluster, query: Application.get_env(:stellar, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Stellar.PubSub},
      {AshAuthentication.Supervisor, otp_app: :stellar},
      {Oban, oban_config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Stellar.Supervisor)
  end
end
