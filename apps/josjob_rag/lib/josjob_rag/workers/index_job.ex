defmodule JosjobRag.Workers.IndexJob do
  @moduledoc "Legacy indexing worker using local vectors by default; CV relevance does not require embeddings."

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 60]

  alias JosjobRag.Analyzer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_id" => job_id}}) do
    case Ash.get(JosjobJob.Job, job_id, load: :organization, authorize?: false) do
      {:ok, job} ->
        with {:ok, _count} <- Analyzer.index_job(job), do: :ok

      {:error, _reason} ->
        # The job was deleted between enqueue and perform; nothing to index.
        :ok
    end
  end

  @doc "Enqueue indexing without making the caller depend on Oban availability."
  def enqueue(job_id) do
    %{"job_id" => to_string(job_id)}
    |> new()
    |> Oban.insert()
  rescue
    _ -> {:error, :oban_unavailable}
  end
end
