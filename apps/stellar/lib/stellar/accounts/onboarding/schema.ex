defmodule Stellar.Accounts.Onboarding.Period do
  @moduledoc "Rentang bulan/tahun (mis. periode kerja/pendidikan). Embedded (jsonb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:month, :integer, public?: true, constraints: [min: 1, max: 12])
    attribute(:year, :integer, public?: true, constraints: [min: 1900, max: 2100])
  end

  actions do
    defaults([:read, :create, :update, :destroy])
    default_accept(:*)
  end
end

defmodule Stellar.Accounts.Onboarding.Employment do
  @moduledoc "Satu entri riwayat kerja (bagian dari `resume`). Embedded (jsonb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:industry, :string, public?: true)
    attribute(:industry_id, :uuid, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:country, :string, public?: true)
    attribute(:country_id, :uuid, public?: true)
    attribute(:position, :string, public?: true)
    attribute(:internship, :boolean, public?: true)
    attribute(:from, Stellar.Accounts.Onboarding.Period, public?: true)
    attribute(:to, Stellar.Accounts.Onboarding.Period, public?: true)
  end

  actions do
    defaults([:read, :create, :update, :destroy])
    default_accept(:*)
  end
end

defmodule Stellar.Accounts.Onboarding.FormalEducation do
  @moduledoc "Satu entri pendidikan formal (bagian dari `education`). Embedded (jsonb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:degree, :string, public?: true)
    attribute(:major, :string, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:country, :string, public?: true)
    attribute(:country_id, :uuid, public?: true)
    # "General" | "Vocational" dsb.
    attribute(:type, :string, public?: true)
    attribute(:from, Stellar.Accounts.Onboarding.Period, public?: true)
    attribute(:to, Stellar.Accounts.Onboarding.Period, public?: true)
  end

  actions do
    defaults([:read, :create, :update, :destroy])
    default_accept(:*)
  end
end

defmodule Stellar.Accounts.Onboarding.Achievement do
  @moduledoc "Sertifikasi/pendidikan non-formal (bagian dari `education`). Embedded (jsonb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    # "Certification" | "Course" | ...
    attribute(:type, :string, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:country, :string, public?: true)
    attribute(:country_id, :uuid, public?: true)
    attribute(:issuer, :string, public?: true)
    attribute(:from, Stellar.Accounts.Onboarding.Period, public?: true)
    attribute(:to, Stellar.Accounts.Onboarding.Period, public?: true)
  end

  actions do
    defaults([:read, :create, :update, :destroy])
    default_accept(:*)
  end
end

defmodule Stellar.Accounts.Onboarding.Resume do
  @moduledoc "Ringkasan profesional worker/graduate: riwayat kerja + skill. Embedded (jsonb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:employments, {:array, Stellar.Accounts.Onboarding.Employment},
      public?: true,
      default: []
    )

    # Skill sebagai label bebas + id master-data (bila ter-resolve).
    attribute(:skills, {:array, :string}, public?: true, default: [])
    attribute(:skill_ids, {:array, :uuid}, public?: true, default: [])
  end

  actions do
    defaults([:read, :create, :update, :destroy])
    default_accept(:*)
  end
end

defmodule Stellar.Accounts.Onboarding.Education do
  @moduledoc "Pendidikan worker/graduate: formal + non-formal/achievement. Embedded (jsonb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:formal, {:array, Stellar.Accounts.Onboarding.FormalEducation},
      public?: true,
      default: []
    )

    attribute(:achievements, {:array, Stellar.Accounts.Onboarding.Achievement},
      public?: true,
      default: []
    )
  end

  actions do
    defaults([:read, :create, :update, :destroy])
    default_accept(:*)
  end
end

defmodule Stellar.Accounts.Onboarding.Interest do
  @moduledoc "Minat worker/graduate: hobi + industri/profesi/negara lain. Embedded (jsonb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:hobbies, {:array, :string}, public?: true, default: [])
    attribute(:industry_ids, {:array, :uuid}, public?: true, default: [])
    attribute(:profession_ids, {:array, :uuid}, public?: true, default: [])
    attribute(:country_ids, {:array, :uuid}, public?: true, default: [])
  end

  actions do
    defaults([:read, :create, :update, :destroy])
    default_accept(:*)
  end
end
