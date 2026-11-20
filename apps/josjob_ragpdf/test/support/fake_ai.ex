defmodule JosjobRagpdf.FakeAI do
  @moduledoc """
  Agent-backed AI module for worker tests.

  Responses are consumed in order for each call to `extract_chunk/2` (or
  `extract_text/2`). A response can be:

    * `{:ok, result, meta}`
    * `{:error, reason}`
    * a plain map, which is wrapped with fake provider metadata
    * a function (`fn path, opts -> response end` or `fn call_index -> response end`)
  """

  @default %{chunk_responses: [], text_responses: [], calls: []}

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    initial = %{
      @default
      | chunk_responses: Keyword.get(opts, :responses, []),
        text_responses: Keyword.get(opts, :text_responses, [])
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

  @spec set_responses(list() | tuple() | map() | function()) :: :ok
  def set_responses(responses) when is_list(responses) do
    Agent.update(__MODULE__, fn state -> %{state | chunk_responses: responses} end)
  end

  def set_responses(responses) when is_function(responses, 1) or is_function(responses, 2) do
    Agent.update(__MODULE__, fn state -> %{state | chunk_responses: responses} end)
  end

  def set_responses(response), do: set_responses([response])

  @spec set_text_responses(list() | tuple() | map() | function()) :: :ok
  def set_text_responses(responses) when is_list(responses) do
    Agent.update(__MODULE__, fn state -> %{state | text_responses: responses} end)
  end

  def set_text_responses(responses) when is_function(responses, 1) or is_function(responses, 2) do
    Agent.update(__MODULE__, fn state -> %{state | text_responses: responses} end)
  end

  def set_text_responses(response), do: set_text_responses([response])

  @doc "Recorded calls, oldest first."
  @spec calls() :: [map()]
  def calls, do: Agent.get(__MODULE__, fn state -> Enum.reverse(state.calls) end)

  @spec chunk_calls() :: [map()]
  def chunk_calls, do: Enum.filter(calls(), &(&1.kind == :chunk))

  @spec text_calls() :: [map()]
  def text_calls, do: Enum.filter(calls(), &(&1.kind == :text))

  @spec reset() :: :ok
  def reset do
    Agent.update(__MODULE__, fn _state -> @default end)
  end

  @spec extract_chunk(String.t(), keyword()) :: {:ok, map(), map()} | {:error, term()}
  def extract_chunk(path, opts) do
    response =
      take_response(:chunk, path, opts, fn call ->
        %{kind: :chunk, path: path, opts: opts, call: call}
      end)

    resolve(response, path, opts)
  end

  @spec extract_text(String.t(), keyword()) :: {:ok, map(), map()} | {:error, term()}
  def extract_text(text, opts) do
    response =
      take_response(:text, text, opts, fn call ->
        %{kind: :text, text: text, opts: opts, call: call}
      end)

    resolve(response, text, opts)
  end

  defp take_response(kind, payload, opts, build_call) do
    Agent.get_and_update(__MODULE__, fn state ->
      responses_key = if kind == :chunk, do: :chunk_responses, else: :text_responses
      responses = Map.fetch!(state, responses_key)
      call_index = length(state.calls)
      {response, remaining} = pop_response(responses, payload, opts, call_index)

      state =
        state
        |> Map.put(:calls, [build_call.(call_index) | state.calls])
        |> Map.put(responses_key, remaining)

      {response, state}
    end)
  end

  defp pop_response(responses, payload, opts, _index) when is_function(responses, 2) do
    {responses.(payload, opts), responses}
  end

  defp pop_response(responses, _payload, _opts, index) when is_function(responses, 1) do
    {responses.(index), responses}
  end

  defp pop_response([response | rest], _payload, _opts, _index), do: {response, rest}
  defp pop_response([], _payload, _opts, _index), do: {{:error, :no_fake_response}, []}
  defp pop_response(response, _payload, _opts, _index), do: {response, response}

  defp resolve(%{} = result, _payload, _opts) do
    {:ok, result, %{provider: "fake", model: "fake-model"}}
  end

  defp resolve({:ok, %{} = result}, _payload, _opts) do
    {:ok, result, %{provider: "fake", model: "fake-model"}}
  end

  defp resolve({:ok, result, meta}, _payload, _opts), do: {:ok, result, meta}
  defp resolve({:error, _reason} = error, _payload, _opts), do: error
  defp resolve(other, _payload, _opts), do: {:error, other}
end
