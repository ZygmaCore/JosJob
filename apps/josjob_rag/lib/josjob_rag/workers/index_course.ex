defmodule JosjobRag.Workers.IndexCourse do
  @moduledoc "Legacy indexing worker using local vectors by default; CV relevance does not require embeddings."

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 60]

  alias JosjobRag.Analyzer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"course_id" => course_id}}) do
    case Ash.get(JosjobLrn.Learning.Course, course_id,
           load: [:section, :industries, :classes],
           authorize?: false
         ) do
      {:ok, course} ->
        with {:ok, _count} <- Analyzer.index_course(course), do: :ok

      {:error, _reason} ->
        :ok
    end
  end

  @doc "Enqueue indexing without making the caller depend on Oban availability."
  def enqueue(course_id) do
    %{"course_id" => to_string(course_id)}
    |> new()
    |> Oban.insert()
  rescue
    _ -> {:error, :oban_unavailable}
  end
end
