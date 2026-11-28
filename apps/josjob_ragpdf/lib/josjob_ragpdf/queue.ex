defmodule JosjobRagpdf.Queue do
  @moduledoc """
  In-memory FIFO job queue.

  Jobs are stored in `JosjobRagpdf.Jobs`; this process only tracks the ids that are
  waiting or running so it can enforce:

    * global concurrency (`:max_concurrency`)
    * per-user concurrency (`:max_active_per_user`)
    * a bounded waiting queue (`:max_queue_size`)

  Workers run under `JosjobRagpdf.TaskSupervisor` with `Task.Supervisor.async_nolink/2`.
  A crashing worker never takes the queue down: the `:DOWN` message marks the
  job as failed and frees its slot.
  """

  use GenServer

  alias JosjobRagpdf.{Job, Jobs, Temp}

  @type entry :: %{id: String.t(), user_id: term(), pid: pid()}

  @impl true
  def init(opts) do
    # Trap exits so the supervisor's shutdown reaches terminate/2, which kills
    # any in-flight workers and removes their temp dirs.
    Process.flag(:trap_exit, true)

    state = %{
      pending: :queue.new(),
      active: %{},
      user_counts: %{},
      ids: MapSet.new(),
      canceled: MapSet.new(),
      timer: nil,
      opts: build_opts(opts)
    }

    {:ok, schedule_cleanup(state)}
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Enqueue a job. Returns its 0-based position among waiting jobs."
  @spec submit(Job.t()) :: {:ok, non_neg_integer()} | {:error, :queue_full | :duplicate}
  def submit(%Job{} = job), do: GenServer.call(__MODULE__, {:submit, job})

  @doc "Cancel a waiting job or kill an active worker. Removes the job from the store."
  @spec cancel(String.t()) :: :ok | {:error, :not_found}
  def cancel(id) when is_binary(id), do: GenServer.call(__MODULE__, {:cancel, id})

  @spec stats() :: %{
          queued: non_neg_integer(),
          active: non_neg_integer(),
          max_concurrency: non_neg_integer(),
          max_queue_size: non_neg_integer()
        }
  def stats, do: GenServer.call(__MODULE__, :stats)

  @doc "Stop all workers and clear the job store. Intended for tests only."
  @spec reset() :: :ok
  def reset, do: GenServer.call(__MODULE__, :reset, 30_000)

  @impl true
  def handle_call({:submit, %Job{} = job}, _from, state) do
    cond do
      MapSet.member?(state.ids, job.id) ->
        {:reply, {:error, :duplicate}, state}

      :queue.len(state.pending) >= state.opts.max_queue_size ->
        {:reply, {:error, :queue_full}, state}

      true ->
        pending = :queue.in(job.id, state.pending)
        position = :queue.len(pending) - 1

        state = %{
          state
          | pending: pending,
            ids: MapSet.put(state.ids, job.id)
        }

        {:reply, {:ok, position}, dispatch(state)}
    end
  end

  def handle_call({:cancel, id}, _from, state) do
    if :queue.member(id, state.pending) do
      pending = :queue.delete(id, state.pending)
      state = %{state | pending: pending, ids: MapSet.delete(state.ids, id)}

      Jobs.delete(id)
      Temp.cleanup(id)

      {:reply, :ok, dispatch(state)}
    else
      case find_active(state.active, id) do
        {_ref, entry} ->
          # Keep the id in `ids` and remember the cancellation until the DOWN
          # message arrives; that DOWN then knows not to resurrect the job.
          Process.exit(entry.pid, :kill)
          Jobs.delete(id)
          Temp.cleanup(id)

          state = %{state | canceled: MapSet.put(state.canceled, id)}
          {:reply, :ok, state}

        nil ->
          {:reply, {:error, :not_found}, state}
      end
    end
  end

  def handle_call(:stats, _from, state) do
    reply = %{
      queued: :queue.len(state.pending),
      active: map_size(state.active),
      max_concurrency: state.opts.max_concurrency,
      max_queue_size: state.opts.max_queue_size
    }

    {:reply, reply, state}
  end

  def handle_call(:reset, _from, state) do
    kill_tasks(state.active)
    Enum.each(MapSet.to_list(state.ids), &Temp.cleanup/1)
    Jobs.clear()

    state = %{
      state
      | pending: :queue.new(),
        active: %{},
        user_counts: %{},
        ids: MapSet.new(),
        canceled: MapSet.new()
    }

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.active, ref) do
      {nil, _active} ->
        {:noreply, state}

      {entry, active} ->
        canceled? = MapSet.member?(state.canceled, entry.id)

        state = %{
          state
          | active: active,
            ids: MapSet.delete(state.ids, entry.id),
            canceled: MapSet.delete(state.canceled, entry.id)
        }

        state = decrement_user(state, entry.user_id)
        handle_worker_down(entry, reason, canceled?)
        {:noreply, dispatch(state)}
    end
  end

  def handle_info(:cleanup, state) do
    cleanup_finished_jobs(state.opts.job_ttl_seconds)
    {:noreply, schedule_cleanup(%{state | timer: nil})}
  end

  # Tasks started with async_nolink send `{ref, result}` on success before the
  # DOWN. The DOWN handler is the single place where slots are released.
  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    kill_tasks(state.active)
    Enum.each(MapSet.to_list(state.ids), &Temp.cleanup/1)
    :ok
  end

  ## Dispatch

  defp dispatch(state) do
    if map_size(state.active) < state.opts.max_concurrency do
      case take_next_eligible(state) do
        {:ok, job, state} ->
          case start_job(job, state) do
            {:ok, state} -> dispatch(state)
            {:error, state} -> dispatch(state)
          end

        :none ->
          state
      end
    else
      state
    end
  end

  # Scan FIFO order, skipping jobs whose user is at the cap. Only the chosen
  # job is removed; skipped jobs keep their relative order.
  defp take_next_eligible(state) do
    list = :queue.to_list(state.pending)

    case find_eligible(list, state.user_counts, state.opts.max_active_per_user, []) do
      {:job, job, remaining} ->
        state = %{state | pending: :queue.from_list(remaining)}
        {:ok, job, state}

      {:missing, id, remaining} ->
        state = %{
          state
          | pending: :queue.from_list(remaining),
            ids: MapSet.delete(state.ids, id)
        }

        take_next_eligible(state)

      :none ->
        :none
    end
  end

  defp find_eligible([], _counts, _max, _skipped), do: :none

  defp find_eligible([id | rest], counts, max, skipped) do
    case Jobs.get(id) do
      {:ok, job} ->
        if Map.get(counts, job.user_id, 0) < max do
          {:job, job, Enum.reverse(skipped) ++ rest}
        else
          find_eligible(rest, counts, max, [id | skipped])
        end

      {:error, :not_found} ->
        # A job can disappear between submit and dispatch (for example when a
        # test resets the store). Drop it instead of crashing.
        {:missing, id, Enum.reverse(skipped) ++ rest}
    end
  end

  defp start_job(job, state) do
    try do
      task =
        Task.Supervisor.async_nolink(state.opts.task_supervisor, fn ->
          state.opts.worker.run(job)
        end)

      entry = %{id: job.id, user_id: job.user_id, pid: task.pid}

      state = %{
        state
        | active: Map.put(state.active, task.ref, entry),
          user_counts: Map.update(state.user_counts, job.user_id, 1, &(&1 + 1))
      }

      {:ok, state}
    rescue
      _exception -> {:error, failed_to_start(job, state)}
    catch
      _kind, _reason -> {:error, failed_to_start(job, state)}
    end
  end

  defp failed_to_start(job, state) do
    finish_job(job.id, %{status: :failed, error: "Worker could not be started"})
    Temp.cleanup(job.id)
    %{state | ids: MapSet.delete(state.ids, job.id)}
  end

  ## DOWN handling

  defp handle_worker_down(entry, _reason, true) do
    # The job was canceled while active: cancel/1 already removed the store
    # entry and temp dir. Make sure no stale state survives.
    Jobs.delete(entry.id)
    Temp.cleanup(entry.id)
  end

  defp handle_worker_down(entry, reason, false) do
    if reason != :normal do
      mark_failed(entry.id, reason)
    end

    Temp.cleanup(entry.id)
  end

  defp mark_failed(id, reason) do
    error = safe_failure(reason)

    Jobs.update(id, fn job ->
      if Job.terminal?(job) do
        %{}
      else
        %{status: :failed, error: error, finished_at: DateTime.utc_now()}
      end
    end)
  rescue
    _exception -> {:error, :not_found}
  catch
    _kind, _reason -> {:error, :not_found}
  end

  defp safe_failure(:killed), do: "Worker was stopped"
  defp safe_failure(:shutdown), do: "Worker was stopped"
  defp safe_failure({:shutdown, _}), do: "Worker was stopped"
  defp safe_failure(:timeout), do: "Worker timed out"
  defp safe_failure(_reason), do: "Worker crashed"

  defp decrement_user(state, user_id) do
    counts =
      case Map.get(state.user_counts, user_id, 0) do
        count when count <= 1 -> Map.delete(state.user_counts, user_id)
        count -> Map.put(state.user_counts, user_id, count - 1)
      end

    %{state | user_counts: counts}
  end

  defp find_active(active, id) do
    Enum.find(active, fn {_ref, entry} -> entry.id == id end)
  end

  ## Cleanup

  defp cleanup_finished_jobs(ttl_seconds) do
    case Jobs.cleanup(ttl_seconds) do
      {:ok, deleted} -> Enum.each(deleted, fn job -> Temp.cleanup(job.id) end)
      _ -> :ok
    end
  rescue
    _exception -> :ok
  catch
    _kind, _reason -> :ok
  end

  defp schedule_cleanup(state) do
    case state.opts.cleanup_interval_ms do
      ms when is_integer(ms) and ms > 0 ->
        timer = Process.send_after(self(), :cleanup, ms)
        %{state | timer: timer}

      _ ->
        %{state | timer: nil}
    end
  end

  ## Runtime helpers

  defp kill_tasks(active) do
    Enum.each(active, fn {ref, entry} ->
      Process.demonitor(ref, [:flush])
      Process.unlink(entry.pid)
      Process.exit(entry.pid, :kill)
    end)
  end

  defp finish_job(id, attrs) do
    attrs = Map.put(attrs, :finished_at, DateTime.utc_now())

    try do
      Jobs.update(id, attrs)
    rescue
      _exception -> {:error, :not_found}
    catch
      _kind, _reason -> {:error, :not_found}
    end
  end

  defp build_opts(opts) do
    %{
      max_concurrency:
        positive_int(Keyword.get(opts, :max_concurrency, config(:max_concurrency, 1)), 1),
      max_active_per_user:
        positive_int(Keyword.get(opts, :max_active_per_user, config(:max_active_per_user, 1)), 1),
      max_queue_size:
        non_neg_int(Keyword.get(opts, :max_queue_size, config(:max_queue_size, 50)), 50),
      cleanup_interval_ms:
        Keyword.get(opts, :cleanup_interval_ms, config(:cleanup_interval_ms, 60_000)),
      job_ttl_seconds:
        non_neg_int(Keyword.get(opts, :job_ttl_seconds, config(:job_ttl_seconds, 3_600)), 3_600),
      worker: Keyword.get(opts, :worker, JosjobRagpdf.Worker),
      task_supervisor: Keyword.get(opts, :task_supervisor, JosjobRagpdf.TaskSupervisor)
    }
  end

  defp config(key, default), do: Application.get_env(:josjob_ragpdf, key, default)

  defp positive_int(value, _default) when is_integer(value) and value > 0, do: value
  defp positive_int(_value, default), do: default

  defp non_neg_int(value, _default) when is_integer(value) and value >= 0, do: value
  defp non_neg_int(_value, default), do: default
end
