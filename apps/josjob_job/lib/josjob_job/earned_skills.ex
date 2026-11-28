defmodule JosjobJob.EarnedSkills do
  import Ecto.Query
  alias Josjob.{Repo}
  alias JosjobJob.CourseAward

  def list(user) do
    Repo.all(from(a in CourseAward, where: a.user_id == ^user.id, order_by: a.completed_at))
    |> Enum.flat_map(& &1.skill_tags)
    |> Enum.uniq_by(&String.downcase/1)
  end

  def merge(user, skills) do
    ((skills || []) ++ list(user))
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&String.downcase/1)
  end
end
