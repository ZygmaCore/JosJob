defmodule JosjobMs.MixProject do
  use Mix.Project

  def project do
    [
      app: :josjob_ms,
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
  #
  # App leaf: TANPA dependency umbrella (in_umbrella) agar `:josjob`/`:josjob_web`
  # bisa bergantung padanya tanpa siklus. Hanya HTTP client + crypto webhook.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug_crypto, "~> 2.0"}
    ]
  end
end
