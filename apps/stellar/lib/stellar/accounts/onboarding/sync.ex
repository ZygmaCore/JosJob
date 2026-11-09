defmodule Stellar.Accounts.Onboarding.Sync do
  @moduledoc """
  Memproyeksikan snapshot jawaban onboarding (blob `Profile.answers`) ke
  penyimpanan TERSTRUKTUR, sesuai peran akun:

    * `:personal`     (worker/graduate) -> `Stellar.Accounts.UserDetail`
      (`resume`, `education`, `interest` — embedded/JSON schema).
    * `:organization` (employer/coordinator) -> `Stellar.Orgs.Organization`
      (relasional; hanya info korporasi/institusi yang disimpan).

  Best-effort: dipanggil SETELAH `Profile` (sumber mentah) tersimpan. Kegagalan
  proyeksi (mis. bentuk data tak valid) di-log dan TIDAK menggagalkan request —
  `Profile.answers` tetap jadi sumber kebenaran.
  """
  require Logger
  require Ash.Query

  alias Stellar.Accounts.UserDetail
  alias Stellar.Orgs.Organization

  @doc "Proyeksikan `answers` ke penyimpanan terstruktur untuk `user`. Selalu `:ok`."
  def project(user, answers) when is_map(answers) do
    case user.account_type do
      :organization -> safe(fn -> upsert_org(user, answers) end, "organization")
      _ -> safe(fn -> upsert_detail(user, answers) end, "user_detail")
    end

    :ok
  end

  def project(_user, _answers), do: :ok

  # ---- personal: worker/graduate -> UserDetail ------------------------------

  defp upsert_detail(user, answers) do
    UserDetail
    |> Ash.Changeset.for_create(:upsert_details, %{
      user_id: user.id,
      resume: %{
        "employments" => list(answers, "employments"),
        "skills" => list(answers, "skills"),
        "skill_ids" => list(answers, "skill_ids")
      },
      education: %{
        "formal" => list(answers, "educations"),
        "achievements" => list(answers, "achievements")
      },
      interest: %{
        "hobbies" => list(answers, "hobbies"),
        "industry_ids" => list(answers, "other_industry_ids"),
        "profession_ids" => list(answers, "other_profession_ids"),
        "country_ids" => list(answers, "other_country_ids")
      }
    })
    |> Ash.create!(authorize?: false)
  end

  # ---- organization: employer/coordinator -> Orgs.Organization --------------

  defp upsert_org(user, answers) do
    name = str(answers["orgName"])

    if name == "" do
      :ok
    else
      role = str(answers["orgRole"])

      case Organization
           |> Ash.Query.filter(user_id == ^user.id)
           |> Ash.read_one!(authorize?: false) do
        nil ->
          Organization
          |> Ash.Changeset.for_create(:create, %{
            name: name,
            additional_info: role,
            user_id: user.id
          })
          |> Ash.create!(authorize?: false)

        org ->
          org
          |> Ash.Changeset.for_update(:update, %{name: name, additional_info: role})
          |> Ash.update!(authorize?: false)
      end
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp list(answers, key) do
    case Map.get(answers, key) do
      l when is_list(l) -> l
      _ -> []
    end
  end

  defp str(v) when is_binary(v), do: String.trim(v)
  defp str(_), do: ""

  defp safe(fun, label) do
    fun.()
  rescue
    e ->
      Logger.warning("Onboarding.Sync #{label} gagal: #{Exception.message(e)}")
      :error
  end
end
