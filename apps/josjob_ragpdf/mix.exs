defmodule JosjobRagpdf.MixProject do
  use Mix.Project

  def project do
    [
      app: :josjob_ragpdf,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {JosjobRagpdf.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:bandit, "~> 1.12"},
      {:plug, "~> 1.20"},
      {:req, "~> 0.6"},
      {:jason, "~> 1.4"},
      {:dotenvy, "~> 1.0"}
    ]
  end
end
