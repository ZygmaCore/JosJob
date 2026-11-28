defmodule JosjobRt.MixProject do
  use Mix.Project

  def project do
    [
      app: :josjob_rt,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:josjob, in_umbrella: true},
      {:josjob_job, in_umbrella: true},
      {:josjob_lrn, in_umbrella: true},
      {:ecto_sql, "~> 3.13"},
      {:phoenix_pubsub, "~> 2.1"}
    ]
  end
end
