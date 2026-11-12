defmodule Josjob.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      apps: [
        :josjob,
        :josjob_job,
        :josjob_lrn,
        :josjob_ai,
        :josjob_doc,
        :josjob_ms,
        :josjob_quiz,
        :josjob_rag,
        :josjob_rt,
        :josjob_web
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

  # Definisi release umbrella. Satu release `josjob` yang memuat SEMUA app
  # umbrella (termasuk josjob_web yang menjalankan endpoint Phoenix).
  # Dibangun di Dockerfile via `MIX_ENV=prod mix release josjob`.
  defp releases do
    [
      josjob: [
        version: "0.1.0",
        applications: [
          josjob: :permanent,
          josjob_ai: :permanent,
          josjob_doc: :permanent,
          josjob_job: :permanent,
          josjob_lrn: :permanent,
          josjob_ms: :permanent,
          josjob_quiz: :permanent,
          josjob_rag: :permanent,
          josjob_rt: :permanent,
          josjob_web: :permanent
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
      # Bootstrap the shared Repo before the first umbrella app starts its tests.
      # Child-app aliases run too late when an earlier app starts the core Repo.
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
