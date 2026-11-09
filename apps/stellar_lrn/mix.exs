defmodule StellarLrn.MixProject do
  use Mix.Project

  def project do
    [
      app: :stellar_lrn,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # User/Org/Industry/Repo live in :stellar; documents (Material) in :stellar_doc.
      {:stellar, in_umbrella: true},
      {:stellar_doc, in_umbrella: true},
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"}
    ]
  end
end
