defmodule JosjobRagpdf.Jobs do
  @moduledoc """
  ETS-backed job store.

  The table is public so queued/active workers can update their own progress
  without routing every chunk update through this GenServer. The GenServer only
  owns the table lifecycle.
  """

  use GenServer
  alias JosjobRagpdf.Job

  @table :josjob_ragpdf_jobs

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end

  @spec create(Job.t()) :: :ok | {:error, :exists}
  def create(%Job{} = job) do
    if :ets.insert_new(@table, {job.id, job}), do: :ok, else: {:error, :exists}
  end

  @spec get(String.t()) :: {:ok, Job.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case :ets.lookup(@table, id) do
      [{^id, job}] -> {:ok, job}
      [] -> {:error, :not_found}
    end
  end

  @spec update(String.t(), map() | (Job.t() -> map())) ::
          {:ok, Job.t()} | {:error, :not_found}
  def update(id, changes) when is_map(changes) do
    update(id, fn _job -> changes end)
  end

  def update(id, fun) when is_function(fun, 1) and is_binary(id) do
    case get(id) do
      {:ok, job} ->
        updated =
          job
          |> fun.()
          |> then(&struct(job, &1))

        :ets.insert(@table, {id, updated})
        {:ok, updated}

      {:error, :not_found} = error ->
        error
    end
  end

  @spec delete(String.t()) :: :ok
  def delete(id) when is_binary(id) do
    :ets.delete(@table, id)
    :ok
  end

  @spec all() :: [Job.t()]
  def all do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, job} -> job end)
  end

  @spec find_by_idempotency(String.t() | nil) :: {:ok, Job.t()} | {:error, :not_found}
  def find_by_idempotency(nil), do: {:error, :not_found}

  def find_by_idempotency(key) when is_binary(key) do
    case Enum.find(all(), &(&1.idempotency_key == key)) do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  @doc "Delete finished jobs older than `ttl_seconds`; return the deleted jobs."
  @spec cleanup(non_neg_integer()) :: {:ok, [Job.t()]}
  def cleanup(ttl_seconds) when is_integer(ttl_seconds) and ttl_seconds >= 0 do
    cutoff = DateTime.add(DateTime.utc_now(), -ttl_seconds, :second)

    deleted =
      all()
      |> Enum.filter(fn job ->
        Job.terminal?(job) and not is_nil(job.finished_at) and
          DateTime.compare(job.finished_at, cutoff) == :lt
      end)
      |> Enum.map(fn job ->
        delete(job.id)
        job
      end)

    {:ok, deleted}
  end

  @doc "Remove every job. Intended for tests."
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Serialize a job for HTTP. Internal source/path/idempotency fields are omitted."
  @spec public(Job.t()) :: map()
  def public(%Job{} = job) do
    %{
      id: job.id,
      cv_id: job.cv_id,
      filename: job.filename,
      status: Job.status_string(job),
      pages: job.pages,
      chunks_total: job.chunks_total,
      chunks_done: job.chunks_done,
      progress: progress(job),
      provider: job.provider,
      model: job.model,
      warnings: job.warnings || [],
      result: job.result,
      error: job.error,
      inserted_at: iso(job.inserted_at),
      started_at: iso(job.started_at),
      finished_at: iso(job.finished_at)
    }
  end

  defp progress(%Job{status: status}) when status in [:done, :partial, :unreadable],
    do: 1.0

  defp progress(%Job{chunks_total: total, chunks_done: done})
       when is_integer(total) and total > 0 do
    min(1.0, (done || 0) / total)
  end

  defp progress(_job), do: 0.0

  defp iso(nil), do: nil
  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
