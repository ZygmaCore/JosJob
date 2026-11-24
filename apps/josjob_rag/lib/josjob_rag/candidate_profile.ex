defmodule JosjobRag.CandidateProfile do
  @moduledoc "Keeps reviewed matching facts and the profile shared with employers consistent."
  alias Josjob.Repo
  alias JosjobJob.CurriculumVitae
  alias JosjobRag.{Analyses, Text}

  def cv(user, id \\ nil) do
    with {:ok, cv} <- Analyses.cv(user, id) do
      facts = CurriculumVitae.matching_facts(user)

      if is_map(facts) and (is_nil(id) or facts["cv_id"] == cv["cv_id"]) do
        {:ok, Map.merge(cv, Map.take(facts, ~w(skills experience education)))}
      else
        {:ok, cv}
      end
    end
  end

  def save(user, cv, result) do
    Repo.transaction(fn ->
      with {:ok, id} <- Analyses.save(user, cv, result),
           {:ok, _profile} <-
             CurriculumVitae.use_analyzed_cv(
               user,
               Map.put(cv, "skills", Text.requirement_list(cv["skills"]))
             ) do
        id
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
