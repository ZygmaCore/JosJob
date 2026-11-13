defmodule Josjob.Release do
  @moduledoc """
  Tugas yang dijalankan DI DALAM release (tanpa Mix tersedia), terutama migrasi DB.

  Dipanggil lewat skrip `bin/migrate`:

      bin/josjob eval Josjob.Release.migrate

  Migrasi Ash disimpan sebagai migrasi Ecto biasa di `apps/josjob/priv/repo/migrations`,
  jadi cukup dijalankan dengan `Ecto.Migrator`.

  Seed superuser dijalankan lewat skrip `bin/seed`:

      bin/josjob eval Josjob.Release.seed
  """
  require Ash.Query

  @app :josjob

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Seed idempoten (aman tiap deploy):
  1. katalog `permissions`,
  2. role global/sistem + `role_permissions`,
  3. SATU superuser platform (email dari SEED_SUPERUSER_EMAIL) via `is_superuser`.
  """
  def seed do
    load_app()
    {:ok, _} = Application.ensure_all_started(@app)

    user = seed_superuser()
    org = seed_atveti(user)
    seed_rbac(org)
    countries = seed_countries()
    industries = seed_industries()
    professions = seed_professions()
    skills = seed_skills()
    catalog = seed_catalog_safe()

    IO.puts("""
    Seed selesai.
      Superuser   : #{user.email} (is_superuser=#{user.is_superuser})
      Org         : #{org.name} (id=#{org.id}, owner=#{user.email})
      Roles       : milik org #{org.name}
      Countries   : #{countries} negara
      Industries  : #{industries} industri
      Professions : #{professions} profesi
      Skills      : #{skills} skill
      Catalog     : #{catalog} course sampel (org #{org.name})
    """)

    user
  end

  # Seed katalog sampel (Section/Course/Class) untuk org awal. Logika ada di
  # `JosjobLrn.Seeds` (app :josjob_lrn, yang boleh depend :josjob) dan
  # dipanggil via `apply/3` — bukan `JosjobLrn.Seeds.seed()` langsung — supaya
  # TIDAK ada dependency edge :josjob -> :josjob_lrn (itu bikin cycle umbrella
  # dan mematahkan `mix compile --warnings-as-errors`). No-op bila modulnya
  # belum ada.
  defp seed_catalog_safe do
    mod = JosjobLrn.Seeds

    if Code.ensure_loaded?(mod) and function_exported?(mod, :seed, 0) do
      apply(mod, :seed, [])
    else
      0
    end
  rescue
    # Sample-catalog seeding is best-effort: it must never abort the critical
    # superuser/RBAC/master-data seed above. Log and carry on.
    e ->
      IO.puts("Seed katalog dilewati (error: #{Exception.message(e)}).")
      0
  end

  # Master data negara (ISO 3166-1). Idempoten via upsert code.
  defp seed_countries do
    alias Josjob.Orgs.Country

    Enum.each(Josjob.Orgs.CountryData.all(), fn %{code: code, name: name, phone_code: phone} ->
      Country
      |> Ash.Changeset.for_create(:create, %{code: code, name: name, phone_code: phone})
      |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_code)
    end)

    length(Josjob.Orgs.CountryData.all())
  end

  # Master data industri level atas. Idempoten via upsert name.
  defp seed_industries do
    alias Josjob.Orgs.Industry

    Enum.each(Josjob.Orgs.IndustryData.all(), fn name ->
      Industry
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_name)
    end)

    length(Josjob.Orgs.IndustryData.all())
  end

  # Master data profesi. Idempoten via upsert name.
  defp seed_professions do
    alias Josjob.Orgs.Profession

    Enum.each(Josjob.Orgs.ProfessionData.all(), fn name ->
      Profession
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_name)
    end)

    length(Josjob.Orgs.ProfessionData.all())
  end

  # Master data skill: umum (industry_id nil) + spesifik per industri (resolve
  # industry_id dari nama). Idempoten via upsert name; re-seed mem-backfill
  # industry_id skill lama. WAJIB dijalankan SETELAH seed_industries.
  defp seed_skills do
    alias Josjob.Orgs.{Industry, Skill}

    Enum.each(Josjob.Orgs.SkillData.general(), fn name ->
      upsert_skill(Skill, name, nil)
    end)

    Enum.each(Josjob.Orgs.SkillData.by_industry(), fn {industry_name, skills} ->
      industry =
        Industry
        |> Ash.Query.filter(name == ^industry_name)
        |> Ash.read_one!(authorize?: false)

      industry_id = industry && industry.id
      Enum.each(skills, fn name -> upsert_skill(Skill, name, industry_id) end)
    end)

    length(Josjob.Orgs.SkillData.all())
  end

  defp upsert_skill(skill_mod, name, industry_id) do
    skill_mod
    |> Ash.Changeset.for_create(:create, %{name: name, industry_id: industry_id})
    |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_name)
  end

  # Organisasi awal "Atveti", pemilik = superuser. Idempoten (cari by name).
  defp seed_atveti(owner) do
    alias Josjob.Orgs.Organization

    case Organization |> Ash.Query.filter(name == "Atveti") |> Ash.read_one!(authorize?: false) do
      nil ->
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Atveti", user_id: owner.id})
        |> Ash.create!(authorize?: false)

      org ->
        org
    end
  end

  # Superuser platform. Diberi PASSWORD (SEED_SUPERUSER_PASSWORD, default
  # "superuser123") supaya bisa login lewat app Flutter (email+password), lalu
  # ditandai onboarding selesai agar langsung mendarat di dashboard (bukan
  # onboarding). Idempoten: baris lama di-backfill password bila belum ada.
  defp seed_superuser do
    alias Josjob.Accounts.User

    email = System.get_env("SEED_SUPERUSER_EMAIL") || "superuser@gmail.com"
    full_name = System.get_env("SEED_SUPERUSER_NAME") || "Super Admin"
    password = System.get_env("SEED_SUPERUSER_PASSWORD") || "superuser123"

    existing =
      User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)

    case existing do
      nil ->
        User
        |> Ash.Changeset.for_create(:register_with_email, %{
          email: email,
          full_name: full_name,
          password: password
        })
        |> Ash.create!(authorize?: false)
        |> promote_superuser()

      %User{} = u ->
        promote_superuser(u, password)
    end
  end

  # Set is_superuser + tandai onboarding selesai; backfill hashed_password bila
  # user lama belum punya (mis. hasil sign-in Google).
  defp promote_superuser(user, password \\ nil) do
    # NOTE: attributes not in the :update action's accept list (mandatory_completed,
    # onboarding_progress, hashed_password) must be set with force_change_attribute/3
    # AFTER for_update — a plain change_attribute is silently dropped once the
    # changeset has been built for an action.
    user
    |> Ash.Changeset.for_update(:update, %{is_superuser: true})
    |> Ash.Changeset.force_change_attribute(:mandatory_completed, true)
    |> Ash.Changeset.force_change_attribute(:onboarding_progress, 100)
    |> maybe_set_password(user, password)
    |> Ash.update!(authorize?: false)
  end

  defp maybe_set_password(changeset, %{hashed_password: nil}, password)
       when is_binary(password) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :hashed_password,
      Bcrypt.hash_pwd_salt(password)
    )
  end

  defp maybe_set_password(changeset, _user, _password), do: changeset

  # Seed permissions (katalog) + role sistem per-role untuk `org`. Definisi
  # kanonik ada di Josjob.Rbac.Catalog; provisioning idempoten.
  defp seed_rbac(org) do
    Josjob.Rbac.Provisioning.ensure_permissions!()

    Enum.each(Map.keys(Josjob.Rbac.Catalog.roles()), fn role_key ->
      Josjob.Rbac.Provisioning.ensure_org_role!(org.id, role_key)
    end)
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
