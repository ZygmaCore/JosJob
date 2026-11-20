defmodule JosjobRagpdf.FakePDF do
  @moduledoc """
  Agent-backed, controllable PDF module for worker tests.

  Configure it with `set/1`; every function used by `JosjobRagpdf.Worker` reads the
  current configuration. Values may be plain terms, or functions that receive
  the call arguments (useful for per-chunk behavior).
  """

  @default %{
    validate: :ok,
    page_count: 2,
    chunk_ranges: nil,
    split: :ok,
    text: {:ok, "fake pdf text"}
  }

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    initial = Map.merge(@default, Keyword.get(opts, :state, %{}))
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

  @spec set(map()) :: :ok
  def set(overrides) when is_map(overrides) do
    Agent.update(__MODULE__, fn state -> Map.merge(state, overrides) end)
  end

  @spec reset() :: :ok
  def reset do
    Agent.update(__MODULE__, fn _state -> @default end)
  end

  @spec state() :: map()
  def state, do: Agent.get(__MODULE__, & &1)

  @spec validate(String.t()) :: :ok | {:error, term()}
  def validate(path), do: resolve(:validate, [path])

  @spec page_count(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def page_count(path) do
    case resolve(:page_count, [path]) do
      count when is_integer(count) -> {:ok, count}
      other -> other
    end
  end

  @spec chunk_ranges(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: [
          {pos_integer(), pos_integer()}
        ]
  def chunk_ranges(total, max_pages \\ 6, overlap \\ 1) do
    case get(:chunk_ranges) do
      fun when is_function(fun, 3) -> fun.(total, max_pages, overlap)
      nil -> compute_ranges(total, max_pages, overlap)
      ranges when is_list(ranges) -> ranges
      _other -> compute_ranges(total, max_pages, overlap)
    end
  end

  @spec split(String.t(), {pos_integer(), pos_integer()}, String.t()) :: :ok | {:error, term()}
  def split(path, range, output_path) do
    case get(:split) do
      fun when is_function(fun, 3) ->
        fun.(path, range, output_path)

      responses when is_map(responses) ->
        Map.get(responses, range, Map.get(responses, :default, :ok))

      response ->
        response
    end
  end

  @spec text(String.t()) :: {:ok, binary()} | {:error, term()}
  def text(path), do: resolve(:text, [path])

  defp get(key), do: Agent.get(__MODULE__, &Map.get(&1, key))

  defp resolve(key, args) do
    case get(key) do
      fun when is_function(fun, length(args)) -> apply(fun, args)
      fun when is_function(fun, 0) -> fun.()
      value -> value
    end
  end

  # Mirrors CONTRACT.md: chunks never exceed max_pages, overlap is clamped,
  # every chunk advances.
  defp compute_ranges(total, max_pages, overlap) do
    cond do
      not is_integer(total) or total <= 0 ->
        []

      not is_integer(max_pages) or max_pages <= 0 ->
        []

      total <= max_pages ->
        [{1, total}]

      true ->
        overlap = overlap |> normalize_overlap() |> min(max_pages - 1)
        build_ranges(1, total, max_pages, overlap, [])
    end
  end

  defp normalize_overlap(overlap) when is_integer(overlap) and overlap >= 0, do: overlap
  defp normalize_overlap(_overlap), do: 0

  defp build_ranges(first, total, max_pages, overlap, acc) do
    last = min(first + max_pages - 1, total)
    acc = [{first, last} | acc]

    if last >= total do
      Enum.reverse(acc)
    else
      next_first = max(last - overlap + 1, first + 1)
      build_ranges(next_first, total, max_pages, overlap, acc)
    end
  end
end
