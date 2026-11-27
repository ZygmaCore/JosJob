# Explicit local/demo catalog, never invoked automatically at startup.
# MIX_ENV=dev mix run apps/josjob/priv/repo/job_skill_course_seeds.exs
case JosjobLrn.JobSkillSeeds.seed() do
  {:ok, summary} -> IO.puts(Jason.encode!(summary, pretty: true))
  {:error, reason} -> raise "Job skill course seed failed: #{inspect(reason)}"
end
