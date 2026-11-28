defmodule JosjobRagpdf.Retry do
  @moduledoc """
  Small retry helper with exponential backoff and jitter.

  Only transient failures are retried by default: timeouts, refused/closed
  connections, HTTP 429 and HTTP 5xx. `JosjobRagpdf.HTTP` returns non-2xx responses
  as `{:ok, %{status: status}}`, so both result shapes are understood.

      JosjobRagpdf.Retry.with_retry(fn -> client.post(url, opts) end,
        max_attempts: 3,
        base_delay_ms: 1_000
      )
  """

  @default_max_attempts 3
  @default_base_delay_ms 1_000
  @default_max_delay_ms 10_000

  @retryable_errors [:timeout, :econnrefused, :closed]

  @type result :: {:ok, term()} | {:error, term()}

  @doc """
  Run `fun` until it returns a non-retryable result or attempts run out.

  Returns the last result produced by `fun`.
  """
  @spec with_retry((-> result()), keyword()) :: result()
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_attempts = positive_integer(opts[:max_attempts], @default_max_attempts)
    base_delay_ms = non_negative_integer(opts[:base_delay_ms], @default_base_delay_ms)
    max_delay_ms = non_negative_integer(opts[:max_delay_ms], @default_max_delay_ms)
    retryable = opts[:retryable] || (&default_retryable?/1)

    attempt(fun, 1, max_attempts, base_delay_ms, max_delay_ms, retryable)
  end

  @doc "Default retryability check."
  @spec default_retryable?(result()) :: boolean()
  def default_retryable?({:error, reason}) when reason in @retryable_errors, do: true

  def default_retryable?({:ok, %{status: status}}) when is_integer(status),
    do: retryable_status?(status)

  def default_retryable?(_result), do: false

  @doc """
  Backoff for `attempt` (1-based): `base * 2^(attempt - 1)`, capped at
  `max_delay_ms`, plus jitter in `0..div(base, 4)`.
  """
  @spec delay_ms(pos_integer(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def delay_ms(attempt, base_delay_ms, max_delay_ms)
      when is_integer(attempt) and attempt > 0 and is_integer(base_delay_ms) and
             is_integer(max_delay_ms) do
    backoff =
      base_delay_ms
      |> Kernel.*(Integer.pow(2, attempt - 1))
      |> min(max(max_delay_ms, 0))

    backoff + jitter(base_delay_ms)
  end

  defp attempt(fun, attempt_number, max_attempts, base_delay_ms, max_delay_ms, retryable) do
    result = fun.()

    cond do
      attempt_number >= max_attempts ->
        result

      not retryable.(result) ->
        result

      true ->
        delay = delay_ms(attempt_number, base_delay_ms, max_delay_ms)
        if delay > 0, do: Process.sleep(delay)
        attempt(fun, attempt_number + 1, max_attempts, base_delay_ms, max_delay_ms, retryable)
    end
  end

  defp jitter(base_delay_ms) when base_delay_ms > 0 do
    :rand.uniform(div(base_delay_ms, 4) + 1) - 1
  end

  defp jitter(_base_delay_ms), do: 0

  defp retryable_status?(status), do: status == 429 or status >= 500

  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp positive_integer(_value, default), do: default

  defp non_negative_integer(value, _default) when is_integer(value) and value >= 0, do: value
  defp non_negative_integer(_value, default), do: default
end
