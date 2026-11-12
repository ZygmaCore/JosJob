defmodule StellarJob do
  @moduledoc "Job listings domain. HTTP callers use StellarJob.Listings for scoped access."
  use Ash.Domain

  resources do
    resource(StellarJob.Job)
  end

  @doc """
  Hello world.

  ## Examples

      iex> StellarJob.hello()
      :world

  """
  def hello do
    :world
  end
end
