defmodule JosjobJob do
  @moduledoc "Job listings domain. HTTP callers use JosjobJob.Listings for scoped access."
  use Ash.Domain

  resources do
    resource(JosjobJob.Job)
  end

  @doc """
  Hello world.

  ## Examples

      iex> JosjobJob.hello()
      :world

  """
  def hello do
    :world
  end
end
