defmodule JosjobLrn.DataCase do
  @moduledoc "Test case that checks out an Ecto sandbox connection on Josjob.Repo."
  use ExUnit.CaseTemplate

  using do
    quote do
      require Ash.Query
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Josjob.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
