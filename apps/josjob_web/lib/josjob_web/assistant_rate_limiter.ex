defmodule JosjobWeb.AssistantRateLimiter do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def allow?(ip), do: GenServer.call(__MODULE__, {:allow, ip})

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:allow, ip}, _from, state) do
    now = System.system_time(:second)
    state = Map.reject(state, fn {_key, {started, _count}} -> now - started >= 60 end)

    case Map.get(state, ip) do
      {_started, count} when count >= 12 -> {:reply, false, state}
      {started, count} -> {:reply, true, Map.put(state, ip, {started, count + 1})}
      nil -> {:reply, true, Map.put(state, ip, {now, 1})}
    end
  end
end
