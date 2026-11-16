defmodule JosjobRagpdf.RetryTest do
  use ExUnit.Case, async: true

  alias JosjobRagpdf.Retry

  describe "with_retry/2" do
    test "returns the first successful result without retrying" do
      {fun, calls} = scripted([{:ok, %{status: 200}}])

      assert {:ok, %{status: 200}} = Retry.with_retry(fun, base_delay_ms: 0)
      assert calls.() == 1
    end

    test "retries 429 and returns the eventual success" do
      {fun, calls} =
        scripted([
          {:ok, %{status: 429}},
          {:ok, %{status: 200, body: "ok"}}
        ])

      assert {:ok, %{status: 200, body: "ok"}} = Retry.with_retry(fun, base_delay_ms: 0)
      assert calls.() == 2
    end

    test "retries 5xx up to max_attempts and returns the last result" do
      {fun, calls} = scripted([{:ok, %{status: 500}}])

      assert {:ok, %{status: 500}} =
               Retry.with_retry(fun, max_attempts: 3, base_delay_ms: 0)

      assert calls.() == 3
    end

    test "does not retry a 400" do
      {fun, calls} = scripted([{:ok, %{status: 400}}])

      assert {:ok, %{status: 400}} = Retry.with_retry(fun, base_delay_ms: 0)
      assert calls.() == 1
    end

    test "retries timeouts and returns the last error" do
      {fun, calls} = scripted([{:error, :timeout}])

      assert {:error, :timeout} = Retry.with_retry(fun, base_delay_ms: 0)
      assert calls.() == 3
    end

    test "retries refused and closed connections" do
      {fun, calls} =
        scripted([
          {:error, :econnrefused},
          {:error, :closed},
          {:ok, %{status: 200}}
        ])

      assert {:ok, %{status: 200}} = Retry.with_retry(fun, base_delay_ms: 0)
      assert calls.() == 3
    end

    test "does not retry non-transient errors" do
      {fun, calls} = scripted([{:error, :invalid_pdf}])

      assert {:error, :invalid_pdf} = Retry.with_retry(fun, base_delay_ms: 0)
      assert calls.() == 1
    end

    test "honours a custom retryable function" do
      {fun, calls} = scripted([{:error, :custom}])

      retryable = fn
        {:error, :custom} -> true
        _other -> false
      end

      assert {:error, :custom} =
               Retry.with_retry(fun, max_attempts: 2, base_delay_ms: 0, retryable: retryable)

      assert calls.() == 2
    end

    test "max_attempts: 1 never retries" do
      {fun, calls} = scripted([{:ok, %{status: 503}}])

      assert {:ok, %{status: 503}} =
               Retry.with_retry(fun, max_attempts: 1, base_delay_ms: 0)

      assert calls.() == 1
    end

    test "a zero base delay never sleeps" do
      {fun, calls} = scripted([{:ok, %{status: 503}}])

      assert {:ok, %{status: 503}} =
               Retry.with_retry(fun, max_attempts: 5, base_delay_ms: 0, max_delay_ms: 0)

      assert calls.() == 5
    end
  end

  describe "default_retryable?/1" do
    test "accepts transient transport errors and 429/5xx" do
      assert Retry.default_retryable?({:error, :timeout})
      assert Retry.default_retryable?({:error, :econnrefused})
      assert Retry.default_retryable?({:error, :closed})
      assert Retry.default_retryable?({:ok, %{status: 429}})
      assert Retry.default_retryable?({:ok, %{status: 500}})
      assert Retry.default_retryable?({:ok, %{status: 503}})
    end

    test "rejects other results" do
      refute Retry.default_retryable?({:ok, %{status: 200}})
      refute Retry.default_retryable?({:ok, %{status: 400}})
      refute Retry.default_retryable?({:ok, %{status: 404}})
      refute Retry.default_retryable?({:error, :invalid_pdf})
      refute Retry.default_retryable?(:ok)
    end
  end

  describe "delay_ms/3" do
    test "grows exponentially with jitter and is capped" do
      first = Retry.delay_ms(1, 1_000, 10_000)
      second = Retry.delay_ms(2, 1_000, 10_000)
      capped = Retry.delay_ms(10, 1_000, 10_000)

      assert first >= 1_000 and first <= 1_250
      assert second >= 2_000 and second <= 2_250
      assert capped >= 10_000 and capped <= 10_250
    end

    test "is zero when the base delay is zero" do
      assert Retry.delay_ms(1, 0, 10_000) == 0
      assert Retry.delay_ms(5, 0, 10_000) == 0
    end
  end

  defp scripted(responses) do
    counter = :counters.new(1, [])
    last = List.last(responses)

    fun = fn ->
      index = :counters.get(counter, 1)
      :counters.add(counter, 1, 1)
      Enum.at(responses, index) || last
    end

    calls = fn -> :counters.get(counter, 1) end

    {fun, calls}
  end
end
