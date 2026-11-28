defmodule Mix.Tasks.JosjobRag.Reindex do
  @shortdoc "Embed all active jobs and courses into pgvector"
  @moduledoc """
  Re-embeds every active job and course.

      mix josjob_rag.reindex
      mix josjob_rag.reindex --force

  `--force` deletes the configured embedding space first. Use it after switching
  providers/models (for example from the local fallback to Gemini).
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [force: :boolean])

    case JosjobRag.Analyzer.reindex_all(force: opts[:force] || false) do
      {:ok, summary} ->
        Mix.shell().info("""
        RAG reindex complete
          jobs:    #{summary.jobs} (#{summary.job_vectors} vectors)
          courses: #{summary.courses} (#{summary.course_vectors} vectors)
          space:   #{summary.provider}/#{summary.model}
        """)

      {:error, reason} ->
        Mix.raise("RAG reindex failed: #{inspect(reason)}")
    end
  end
end
