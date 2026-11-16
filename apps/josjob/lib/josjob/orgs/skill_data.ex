defmodule Josjob.Orgs.SkillData do
  @moduledoc """
  Master data skill: skill UMUM (lintas industri) + skill SPESIFIK per industri.
  Dipakai seed `skills` (`Josjob.Release.seed_skills`). Nama industri pada
  `by_industry/0` HARUS cocok dengan `Josjob.Orgs.IndustryData.all/0` agar
  seed dapat me-resolve `industry_id` (lihat test skill_data_test).
  """

  # Skill umum (tak terikat industri) -> di-seed dengan industry_id = nil, selalu
  # tampil sebagai saran di onboarding apa pun industri yang dipilih.
  @general [
    "Communication",
    "Teamwork",
    "Customer Service",
    "Problem Solving",
    "Time Management",
    "Leadership",
    "Microsoft Office",
    "Safety Compliance"
  ]

  # Skill spesifik per industri. Kunci = nama industri (IndustryData).
  @by_industry %{
    "Hospitality & Tourism" => [
      "Food & Beverage Service",
      "Housekeeping",
      "Front Desk Operations",
      "Event Coordination",
      "Tour Guiding",
      "Barista Skills"
    ],
    "Construction & Trades" => [
      "Carpentry",
      "Welding",
      "Electrical Wiring",
      "Plumbing",
      "Masonry",
      "Blueprint Reading",
      "Heavy Equipment Operation"
    ],
    "Healthcare" => [
      "Patient Care",
      "First Aid & CPR",
      "Medical Records",
      "Infection Control",
      "Phlebotomy",
      "Vital Signs Monitoring"
    ],
    "Manufacturing" => [
      "Machine Operation",
      "Quality Control",
      "Assembly Line",
      "CNC Machining",
      "Lean Manufacturing",
      "Inventory Handling"
    ],
    "Software & IT" => [
      "Python",
      "JavaScript",
      "SQL",
      "Cloud Computing",
      "Version Control (Git)",
      "Networking",
      "Cybersecurity"
    ],
    "Finance" => [
      "Bookkeeping",
      "Financial Analysis",
      "Accounting",
      "Auditing",
      "Tax Preparation",
      "Payroll"
    ],
    "Retail & Sales" => [
      "Cashier Operations",
      "Merchandising",
      "Inventory Management",
      "Point of Sale (POS)",
      "Upselling",
      "Stock Replenishment"
    ],
    "Logistics & Transport" => [
      "Warehouse Management",
      "Forklift Operation",
      "Route Planning",
      "Supply Chain Coordination",
      "Freight Handling",
      "Defensive Driving"
    ]
  }

  @doc "Skill umum (tanpa industri)."
  def general, do: @general

  @doc "Map nama industri -> daftar skill spesifik."
  def by_industry, do: @by_industry

  @doc "Semua nama skill (umum + semua industri), diratakan."
  def all, do: @general ++ (@by_industry |> Map.values() |> List.flatten())
end
