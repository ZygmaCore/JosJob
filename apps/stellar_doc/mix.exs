defmodule StellarDoc.MixProject do
  use Mix.Project

  def project do
    [
      app: :stellar_doc,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
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
      # User/Org/Repo + Rbac (Role/MembershipRole) + Membership ada di :stellar.
      {:stellar, in_umbrella: true},
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"}
    ]
  end
end
