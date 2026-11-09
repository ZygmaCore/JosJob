defmodule Stellar.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      apps: [
        :stellar,
        :stellar_job,
        :stellar_lrn,
        :stellar_ai,
        :stellar_doc,
        :stellar_ms,
        :stellar_quiz,
        :stellar_rag,
        :stellar_rt,
        :stellar_web
      ],
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      # Konsolidasi protokol hanya di prod. Di dev/test, resource Ash yang
      # di-recompile incremental tak lagi memicu warning "Inspect ... already
      # consolidated" (implementasi Inspect-nya tetap berlaku).
      consolidate_protocols: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Definisi release umbrella. Satu release `stellar` yang memuat SEMUA app
  # umbrella (termasuk stellar_web yang menjalankan endpoint Phoenix).
  # Dibangun di Dockerfile via `MIX_ENV=prod mix release stellar`.
  defp releases do
    [
      stellar: [
        version: "0.1.0",
        applications: [
          stellar: :permanent,
          stellar_ai: :permanent,
          stellar_doc: :permanent,
          stellar_job: :permanent,
          stellar_lrn: :permanent,
          stellar_ms: :permanent,
          stellar_quiz: :permanent,
          stellar_rag: :permanent,
          stellar_rt: :permanent,
          stellar_web: :permanent
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp deps do
    [
      # Required to run "mix format" on ~H/.heex files from the umbrella root
      {:phoenix_live_view, ">= 0.0.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  #
  # Aliases listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp aliases do
    [
      # run `mix setup` in all child apps
      setup: ["cmd mix setup"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
