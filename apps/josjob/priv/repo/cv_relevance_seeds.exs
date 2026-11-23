# Explicit local/demo seed; never called by startup or standard seeds.
# MIX_ENV=dev mix run apps/josjob/priv/repo/cv_relevance_seeds.exs
case JosjobRag.DemoSeeds.seed() do
  {:ok, summary} -> IO.puts(Jason.encode!(summary, pretty: true))
  {:error, reason} -> raise "CV relevance demo seed failed: #{inspect(reason)}"
end
