defmodule Josjob.Orgs.IndustryData do
  @moduledoc "Master data industri (level atas). Dipakai seed `industries`."

  # Industri level atas (parent_id = nil). Cocok dengan pilihan onboarding FE.
  @industries [
    "Hospitality & Tourism",
    "Construction & Trades",
    "Healthcare",
    "Manufacturing",
    "Software & IT",
    "Finance",
    "Retail & Sales",
    "Logistics & Transport"
  ]

  @doc "Daftar nama industri level atas."
  def all, do: @industries
end
