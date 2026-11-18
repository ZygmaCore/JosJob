defmodule JosjobJob do
  @moduledoc "Job listings and candidate CV domain. Scoped access lives in Listings and CurriculumVitae."
  use Ash.Domain

  resources do
    resource(JosjobJob.Job)
    resource(JosjobJob.CvProfile)
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
