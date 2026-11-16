defmodule JosjobRagpdf.FakeHTTP do
  @moduledoc """
  Scriptable HTTP client for tests. Never touches the network.

  Start it with a queue of responses:

      start_supervised!({JosjobRagpdf.FakeHTTP, responses: [{:ok, %{status: 200, body: "{}"}}]})

  Every `post/2` / `get/2` pops the next response and records the request.
  Responses are returned verbatim, with two conveniences:

    * a bare `%{status: ..., body: ...}` map is wrapped in `{:ok, ...}`
    * a function (arity 0, 1, or 2) is invoked — arity 2 receives `(url, opts)`

  `download/2` accepts `:ok`, `{:error, reason}`, or `{:ok, %{body: binary}}`;
  a binary body is written to the destination path.

  The agent is registered globally as `JosjobRagpdf.FakeHTTP`, so tests using it must
  be `async: false`.
  """

  use Agent

  @doc "Start the fake with `:responses` (a list, consumed in order)."
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    responses = opts |> Keyword.get(:responses, []) |> List.wrap()

    Agent.start_link(fn -> %{responses: responses, requests: []} end, name: __MODULE__)
  end

  @doc "Replace the response queue."
  @spec set_responses(list()) :: :ok
  def set_responses(responses) when is_list(responses) do
    Agent.update(__MODULE__, fn state -> %{state | responses: responses} end)
  end

  @doc "Append one response to the queue."
  @spec push_response(term()) :: :ok
  def push_response(response) do
    Agent.update(__MODULE__, fn state -> %{state | responses: state.responses ++ [response]} end)
  end

  @doc "Requests recorded so far, oldest first."
  @spec requests() :: [map()]
  def requests do
    case Process.whereis(__MODULE__) do
      nil -> []
      _pid -> Agent.get(__MODULE__, fn state -> Enum.reverse(state.requests) end)
    end
  end

  @doc "Most recent request, or `nil`."
  @spec last_request() :: map() | nil
  def last_request do
    case Process.whereis(__MODULE__) do
      nil ->
        nil

      _pid ->
        Agent.get(__MODULE__, fn
          %{requests: [last | _rest]} -> last
          %{requests: []} -> nil
        end)
    end
  end

  @doc "Drop the response queue and the request log."
  @spec reset() :: :ok
  def reset do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> Agent.update(__MODULE__, fn _state -> %{responses: [], requests: []} end)
    end
  end

  @doc "Record and answer a POST."
  @spec post(String.t(), keyword()) :: term()
  def post(url, opts \\ []) do
    record(%{method: :post, url: url, opts: opts})
    respond(url, opts)
  end

  @doc "Record and answer a GET."
  @spec get(String.t(), keyword()) :: term()
  def get(url, opts \\ []) do
    record(%{method: :get, url: url, opts: opts})
    respond(url, opts)
  end

  @doc "Record and answer a download request."
  @spec download(String.t(), String.t()) :: :ok | {:error, term()}
  def download(url, dest_path) do
    record(%{method: :download, url: url, dest: dest_path, opts: []})

    case respond(url, []) do
      :ok ->
        _ = touch(dest_path)
        :ok

      {:ok, %{body: body}} ->
        write(dest_path, body)

      {:ok, _other} ->
        _ = touch(dest_path)
        :ok

      {:error, _reason} = error ->
        error

      other ->
        other
    end
  end

  defp record(request) do
    Agent.update(__MODULE__, fn state -> %{state | requests: [request | state.requests]} end)
  end

  defp respond(url, opts) do
    response =
      Agent.get_and_update(__MODULE__, fn state ->
        case state.responses do
          [next | rest] -> {next, %{state | responses: rest}}
          [] -> {{:error, :no_fake_response}, state}
        end
      end)

    resolve(response, url, opts)
  end

  defp resolve(fun, url, opts) when is_function(fun, 2), do: fun.(url, opts)
  defp resolve(fun, url, _opts) when is_function(fun, 1), do: fun.(url)
  defp resolve(fun, _url, _opts) when is_function(fun, 0), do: fun.()

  defp resolve(%{status: _status} = response, _url, _opts) do
    {:ok, Map.put_new(response, :headers, [])}
  end

  defp resolve(response, _url, _opts), do: response

  defp write(dest_path, body) do
    File.mkdir_p!(Path.dirname(dest_path))
    data = if is_binary(body), do: body, else: Jason.encode!(body)

    case File.write(dest_path, data) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp touch(dest_path) do
    File.mkdir_p!(Path.dirname(dest_path))

    if File.exists?(dest_path) do
      :ok
    else
      File.write(dest_path, "")
    end
  end
end
