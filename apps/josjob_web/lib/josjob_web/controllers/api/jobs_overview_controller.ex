defmodule JosjobWeb.Api.JobsOverviewController do
  use JosjobWeb, :controller
  require Ash.Query
  alias Josjob.Accounts.Profile
  alias JosjobJob.Listings
  alias JosjobWeb.Api.JobJSON

  def show(conn, _params) do
    user = conn.assigns.current_user

    case Listings.overview(user) do
      {:ok, summary} ->
        json(conn, %{
          data: %{
            stats: summary.stats,
            jobs: Enum.map(summary.jobs, &JobJSON.listing(&1, summary.organizations)),
            organizations: summary.organizations,
            profile: profile(user),
            capabilities: %{matching: false, applications: true, interviews: true}
          }
        })

      {:error, _} ->
        conn |> put_status(503) |> json(%{error: "overview_unavailable"})
    end
  end

  defp profile(user) do
    stored = Profile |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)
    answers = if stored && is_map(stored.answers), do: stored.answers, else: %{}

    skills =
      values(answers, "skills")
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&String.downcase/1)

    %{
      onboarding_progress: user.onboarding_progress,
      mandatory_completed: user.mandatory_completed,
      skills: Enum.take(skills, 8),
      skill_count: length(skills),
      experience_count:
        Enum.count(
          values(answers, "employments"),
          &(named?(&1, "name") or named?(&1, "position"))
        ),
      education_count: Enum.count(values(answers, "educations"), &named?(&1, "name")),
      certificates_saved: user |> JosjobLrn.Certificates.list_for() |> length()
    }
  end

  defp values(answers, key) do
    case Map.get(answers, key) do
      items when is_list(items) -> items
      _ -> []
    end
  end

  defp named?(item, key) when is_map(item) do
    case Map.get(item, key) do
      value when is_binary(value) -> String.trim(value) != ""
      _ -> false
    end
  end

  defp named?(_, _), do: false
end
