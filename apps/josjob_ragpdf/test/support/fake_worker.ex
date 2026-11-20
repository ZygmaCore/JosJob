defmodule JosjobRagpdf.FakeWorker do
  @moduledoc """
  Agent-backed worker used by queue tests.

  Modes:

    * `:instant` — mark the job done immediately
    * `:block` — wait for `release/1` (or a safety timeout)
    * `:crash` — raise so the queue's `:DOWN` recovery path is exercised
    * `:delay` / `{:delay, ms}` — wait for a configurable duration

  When `test_pid` is configured, `run/1` sends `{:fake_worker_started, id}` and
  `{:fake_worker_done, id}` messages so tests can synchronize without sleeping.
  """

  @block_timeout 10_000

  @default %{
    mode: :instant,
    test_pid: nil,
    delay_ms: 0,
    jobs: [],
    started: %{},
    releases: MapSet.new()
  }

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    initial = %{
      @default
      | mode: Keyword.get(opts, :mode, :instant),
        test_pid: Keyword.get(opts, :test_pid),
        delay_ms: Keyword.get(opts, :delay_ms, 0)
    }

    Agent.start_link(fn -> initial end, name: __MODULE__)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary
    }
  end

  @spec set_mode(atom() | tuple(), keyword()) :: :ok
  def set_mode(mode, opts \\ []) do
    Agent.update(__MODULE__, fn state ->
      %{
        state
        | mode: mode,
          test_pid: Keyword.get(opts, :test_pid, state.test_pid),
          delay_ms: Keyword.get(opts, :delay_ms, state.delay_ms)
      }
    end)
  end

  @doc "Recorded jobs, oldest first."
  @spec jobs() :: [JosjobRagpdf.Job.t()]
  def jobs, do: Agent.get(__MODULE__, fn state -> Enum.reverse(state.jobs) end)

  @spec calls() :: [JosjobRagpdf.Job.t()]
  def calls, do: jobs()

  @spec reset() :: :ok
  def reset do
    Agent.update(__MODULE__, fn _state -> @default end)
  end

  @doc "Release a blocked job. Safe to call before the job starts."
  @spec release(String.t()) :: :ok
  def release(id) when is_binary(id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.get(state.started, id) do
        nil ->
          {:ok, %{state | releases: MapSet.put(state.releases, id)}}

        pid ->
          send(pid, {:finish, id})
          {:ok, state}
      end
    end)

    :ok
  end

  def run(%JosjobRagpdf.Job{} = job) do
    worker_pid = self()

    {released?, state} =
      Agent.get_and_update(__MODULE__, fn state ->
        released? = MapSet.member?(state.releases, job.id)

        state = %{
          state
          | jobs: [job | state.jobs],
            started: Map.put(state.started, job.id, worker_pid),
            releases: MapSet.delete(state.releases, job.id)
        }

        {{released?, state}, state}
      end)

    notify(state.test_pid, {:fake_worker_started, job.id})
    JosjobRagpdf.Jobs.update(job.id, %{status: :processing, started_at: DateTime.utc_now()})

    case state.mode do
      :instant ->
        :ok

      :block ->
        unless released?, do: block(job.id)

      :crash ->
        raise "fake worker crash"

      :delay ->
        sleep(state.delay_ms)

      {:delay, ms} when is_integer(ms) ->
        sleep(ms)

      _other ->
        :ok
    end

    JosjobRagpdf.Jobs.update(job.id, %{
      status: :done,
      result: %{
        "skills" => [],
        "experience" => [],
        "education" => [],
        "extraction_confidence" => 1.0
      },
      chunks_total: 1,
      chunks_done: 1,
      provider: "fake",
      model: "fake-model",
      warnings: [],
      error: nil,
      finished_at: DateTime.utc_now()
    })

    notify(state.test_pid, {:fake_worker_done, job.id})
    :ok
  end

  defp block(id) do
    receive do
      {:finish, ^id} -> :ok
    after
      @block_timeout -> :ok
    end
  end

  defp sleep(ms) when is_integer(ms) and ms > 0, do: Process.sleep(ms)
  defp sleep(_ms), do: :ok

  defp notify(nil, _message), do: :ok
  defp notify(pid, message) when is_pid(pid), do: send(pid, message)
  defp notify(_other, _message), do: :ok
end
