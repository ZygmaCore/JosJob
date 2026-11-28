defmodule JosjobRag.Test.FakeVectorStore do
  @moduledoc false
  # In-memory VectorStore used by Analyzer tests (no PostgreSQL required).
  # The Agent pid lives in the test process dictionary; Analyzer runs in the
  # same process, so all calls see the same store.

  @key :josjob_rag_fake_vector_store

  def start! do
    agent = Agent.start_link(fn -> %{} end) |> elem(1)
    Process.put(@key, agent)
    agent
  end

  def dimensions, do: 1536
  def dominant_space(_owner_type), do: {:ok, nil}
  def delete_space(_owner_type, _provider, _model), do: {:ok, 0}

  def hashes(owner_type, owner_ids, provider, model) do
    rows = Agent.get(agent(), & &1)

    hashes =
      for id <- owner_ids,
          row = rows[key(owner_type, id, provider, model)],
          into: %{},
          do: {id, row.hash}

    {:ok, hashes}
  end

  def put_many(rows) do
    Agent.update(agent(), fn state ->
      Enum.reduce(rows, state, fn row, acc ->
        Map.put(acc, key(row.owner_type, row.owner_id, row.provider, row.model), %{
          hash: row.content_hash,
          vector: row.vector
        })
      end)
    end)

    {:ok, length(rows)}
  end

  def put(owner_type, owner_id, text, vector, opts) do
    put_many([
      %{
        owner_type: owner_type,
        owner_id: owner_id,
        text: text,
        vector: vector,
        provider: opts[:provider],
        model: opts[:model],
        content_hash: JosjobRag.VectorStore.content_hash(text)
      }
    ])
  end

  def vectors(owner_type, owner_ids, provider, model) do
    rows = Agent.get(agent(), & &1)

    vectors =
      for id <- owner_ids,
          row = rows[key(owner_type, id, provider, model)],
          into: %{},
          do: {id, row.vector}

    {:ok, vectors}
  end

  defp key(owner_type, id, provider, model) do
    {to_string(owner_type), to_string(id), to_string(provider), to_string(model)}
  end

  defp agent, do: Process.get(@key)
end
