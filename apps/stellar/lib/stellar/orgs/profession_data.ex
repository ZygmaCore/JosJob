defmodule Stellar.Orgs.ProfessionData do
  @moduledoc "Master data profesi. Dipakai seed `professions`."

  # Daftar profesi. Cocok dengan pilihan onboarding FE.
  @professions [
    "Software Engineer",
    "Project Manager",
    "Data Analyst",
    "Registered Nurse",
    "Chef",
    "Electrician",
    "Accountant",
    "Sales Executive"
  ]

  @doc "Daftar nama profesi."
  def all, do: @professions
end
