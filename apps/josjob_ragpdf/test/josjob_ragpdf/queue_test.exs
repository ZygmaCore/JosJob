defmodule JosjobRagpdf.QueueTest do
  use ExUnit.Case, async: false

  alias JosjobRagpdf.{FakeWorker, Job, Jobs, Queue, Temp}

  @receive_timeout 2_000

  @default_opts [
    max_concurrency: 1,
    max_active_per_user: 1,
    max_queue_size: 10,
    cleanup_interval_ms: :infinity,
    job_ttl_seconds: 3_600,
    worker: FakeWorker,
    task_supervisor: JosjobRagpdf.TaskSupervisor
  ]

  setup context do
    # The application owns the default queue (with the real worker). Replace it
    # with a queue that calls the fake worker, then restore the application's
    # queue in on_exit.
    stop_app_queue()
    on_exit(&restore_app_queue/0)

    Jobs.clear()
    start_supervised!(FakeWorker)

    opts = Keyword.merge(@default_opts, context[:queue_opts] || [])
    start_supervised!({Queue, opts})
    FakeWorker.set_mode(:block, test_pid: self())

    :ok
  end

  test "runs jobs in FIFO order with global concurrency one" do
    a = create_job("user-a")
    b = create_job("user-b")
    c = create_job("user-c")

    a_id = a.id
    b_id = b.id
    c_id = c.id

    assert {:ok, 0} = Queue.submit(a)
    assert_receive {:fake_worker_started, ^a_id}, @receive_timeout

    assert {:ok, 0} = Queue.submit(b)
    assert {:ok, 1} = Queue.submit(c)

    refute_received {:fake_worker_started, ^b_id}

    FakeWorker.release(a_id)
    assert_receive {:fake_worker_started, ^b_id}, @receive_timeout
    refute_received {:fake_worker_started, ^c_id}

    FakeWorker.release(b_id)
    assert_receive {:fake_worker_started, ^c_id}, @receive_timeout

    FakeWorker.release(c_id)
    wait_for_status(c_id, :done)
  end

  @tag queue_opts: [max_concurrency: 2, max_active_per_user: 1]
  test "respects global max concurrency" do
    a = create_job("user-a")
    b = create_job("user-b")
    c = create_job("user-c")
    c_id = c.id

    assert {:ok, 0} = Queue.submit(a)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a.id

    assert {:ok, 0} = Queue.submit(b)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == b.id

    assert {:ok, 0} = Queue.submit(c)
    refute_received {:fake_worker_started, ^c_id}

    FakeWorker.release(a.id)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == c.id

    FakeWorker.release(b.id)
    FakeWorker.release(c.id)

    wait_for_status(b.id, :done)
    wait_for_status(c.id, :done)
  end

  @tag queue_opts: [max_concurrency: 2, max_active_per_user: 1]
  test "skips a job whose user is at the per-user cap while another user's job runs" do
    a1 = create_job("user-a")
    a2 = create_job("user-a")
    b1 = create_job("user-b")
    a2_id = a2.id

    assert {:ok, 0} = Queue.submit(a1)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a1.id

    assert {:ok, 0} = Queue.submit(a2)

    assert {:ok, 1} = Queue.submit(b1)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == b1.id

    # a2 is at the head of the queue but user-a is capped; b1 still started.
    refute_received {:fake_worker_started, ^a2_id}
    assert %{queued: 1, active: 2} = Queue.stats()

    FakeWorker.release(a1.id)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a2.id

    FakeWorker.release(a2.id)
    FakeWorker.release(b1.id)

    wait_for_status(a2.id, :done)
    wait_for_status(b1.id, :done)
  end

  @tag queue_opts: [max_concurrency: 1, max_queue_size: 2]
  test "rejects duplicates and submissions when the waiting queue is full" do
    a = create_job("user-a")
    b = create_job("user-b")
    c = create_job("user-c")
    d = create_job("user-d")

    assert {:ok, 0} = Queue.submit(a)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a.id

    assert {:ok, 0} = Queue.submit(b)
    assert {:ok, 1} = Queue.submit(c)

    assert {:error, :queue_full} = Queue.submit(d)
    assert {:error, :duplicate} = Queue.submit(a)
    assert {:error, :duplicate} = Queue.submit(b)

    FakeWorker.release(a.id)
    FakeWorker.release(b.id)
    FakeWorker.release(c.id)

    wait_for_status(c.id, :done)
  end

  test "cancel removes a queued job and its temp dir" do
    a = create_job("user-a")
    b = create_job("user-b")

    assert {:ok, 0} = Queue.submit(a)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a.id

    assert {:ok, 0} = Queue.submit(b)
    assert File.exists?(Temp.job_dir(b.id))

    assert :ok = Queue.cancel(b.id)
    assert {:error, :not_found} = Jobs.get(b.id)
    refute File.exists?(Temp.job_dir(b.id))
    assert %{queued: 0, active: 1} = Queue.stats()
    assert {:error, :not_found} = Queue.cancel(b.id)

    FakeWorker.release(a.id)
    wait_for_status(a.id, :done)
  end

  test "cancel kills an active job, removes it, and frees the slot" do
    a = create_job("user-a")

    assert {:ok, 0} = Queue.submit(a)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a.id
    assert File.exists?(Temp.job_dir(a.id))

    assert :ok = Queue.cancel(a.id)
    assert {:error, :not_found} = Jobs.get(a.id)
    refute File.exists?(Temp.job_dir(a.id))

    wait_until(fn -> Queue.stats().active == 0 end)

    FakeWorker.set_mode(:instant)
    b = create_job("user-b")
    assert {:ok, 0} = Queue.submit(b)
    wait_for_status(b.id, :done)
  end

  test "a crashing worker marks the job failed and frees the slot" do
    FakeWorker.set_mode(:crash)
    a = create_job("user-a")

    assert {:ok, 0} = Queue.submit(a)
    wait_for_status(a.id, :failed)

    assert {:ok, failed} = Jobs.get(a.id)
    assert is_binary(failed.error)
    assert failed.finished_at != nil

    wait_until(fn -> Queue.stats().active == 0 end)

    FakeWorker.set_mode(:instant)
    b = create_job("user-b")
    assert {:ok, 0} = Queue.submit(b)
    wait_for_status(b.id, :done)
  end

  @tag queue_opts: [max_concurrency: 2, max_active_per_user: 1, max_queue_size: 5]
  test "stats reports queue configuration and current load" do
    assert %{
             queued: 0,
             active: 0,
             max_concurrency: 2,
             max_queue_size: 5
           } = Queue.stats()

    a1 = create_job("user-a")
    a2 = create_job("user-a")
    b1 = create_job("user-b")

    assert {:ok, 0} = Queue.submit(a1)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a1.id

    assert {:ok, 0} = Queue.submit(a2)
    assert {:ok, 1} = Queue.submit(b1)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == b1.id

    assert %{
             queued: 1,
             active: 2,
             max_concurrency: 2,
             max_queue_size: 5
           } = Queue.stats()

    FakeWorker.release(a1.id)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a2.id

    FakeWorker.release(a2.id)
    FakeWorker.release(b1.id)
    wait_for_status(a2.id, :done)
    wait_for_status(b1.id, :done)
  end

  test "reset kills active jobs, clears pending jobs, and clears the store" do
    a = create_job("user-a")
    b = create_job("user-b")

    assert {:ok, 0} = Queue.submit(a)
    assert_receive {:fake_worker_started, id}, @receive_timeout
    assert id == a.id
    assert {:ok, 0} = Queue.submit(b)

    assert :ok = Queue.reset()
    assert %{queued: 0, active: 0} = Queue.stats()
    assert Jobs.all() == []
    refute File.exists?(Temp.job_dir(a.id))
    refute File.exists?(Temp.job_dir(b.id))

    FakeWorker.set_mode(:instant)
    c = create_job("user-c")
    assert {:ok, 0} = Queue.submit(c)
    wait_for_status(c.id, :done)
  end

  ## Helpers

  defp create_job(user_id, attrs \\ []) do
    id = Keyword.get(attrs, :id) || JosjobRagpdf.Id.generate()
    attrs = Keyword.put(attrs, :id, id)
    Temp.ensure_job_dir(id)

    job =
      struct(
        %Job{
          id: id,
          user_id: user_id,
          status: :queued,
          inserted_at: DateTime.utc_now(),
          filename: "cv.pdf",
          source: {:upload, Path.join(Temp.job_dir(id), "cv.pdf")}
        },
        attrs
      )

    :ok = Jobs.create(job)
    job
  end

  defp wait_for_status(id, status, timeout \\ @receive_timeout) do
    wait_until(
      fn ->
        case Jobs.get(id) do
          {:ok, %{status: ^status}} -> true
          _other -> false
        end
      end,
      timeout
    )
  end

  defp wait_until(fun, timeout \\ @receive_timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    poll(fun, deadline)
  end

  defp poll(fun, deadline) do
    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        flunk("condition was not met within the timeout")

      true ->
        Process.sleep(10)
        poll(fun, deadline)
    end
  end

  defp stop_app_queue do
    case Process.whereis(Queue) do
      nil ->
        :ok

      _pid ->
        case Supervisor.terminate_child(JosjobRagpdf.Supervisor, Queue) do
          :ok ->
            :ok

          {:error, :not_found} ->
            case Process.whereis(Queue) do
              nil -> :ok
              pid -> GenServer.stop(pid, :normal, 5_000)
            end
        end
    end
  end

  defp restore_app_queue do
    if is_nil(Process.whereis(Queue)) do
      case Supervisor.restart_child(JosjobRagpdf.Supervisor, Queue) do
        {:ok, _pid} ->
          :ok

        {:error, :running} ->
          :ok

        {:error, _reason} ->
          case Supervisor.start_child(JosjobRagpdf.Supervisor, {Queue, []}) do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
            _other -> :ok
          end
      end
    end

    :ok
  end
end
