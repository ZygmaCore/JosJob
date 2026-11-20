defmodule JosjobRag.MixProject do
  use Mix.Project

  def project do
    [
      app: :josjob_rag,
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
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.38.0", runtime: false},
      {:xberg, "~> 1.0.0-rc.14"},
      {:josjob, in_umbrella: true},
      {:josjob_job, in_umbrella: true},
      {:josjob_lrn, in_umbrella: true},
      {:ash, "~> 3.0"},
      {:oban, "~> 2.20"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
