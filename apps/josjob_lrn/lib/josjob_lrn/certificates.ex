defmodule JosjobLrn.Certificates do
  @moduledoc "Private learner certificate records, including certifications already saved during onboarding."
  use Ash.Domain
  require Ash.Query
  alias Josjob.Accounts.Profile
  alias JosjobLrn.Certificates.Certificate
  @fields ~w(title issuer issued_on expires_on credential_id credential_url)

  resources do
    resource Certificate
  end

  def list_for(user) do
    records =
      Certificate
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.sort(created_at: :desc, id: :asc)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&to_json/1)

    Enum.map(JosjobLrn.CourseAwards.list(user), &JosjobLrn.CourseAwards.json/1) ++
      records ++ onboarding_certificates(user)
  end

  def add_certificate(user, attrs) do
    with {:ok, attrs} <- attributes(attrs) do
      Certificate
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.Changeset.force_change_attribute(:user_id, user.id)
      |> Ash.create(authorize?: false)
    end
  end

  def update_certificate(user, id, attrs) do
    with :ok <- editable_award(user, id),
         {:ok, certificate} <- owned(user, id),
         {:ok, attrs} <- attributes(attrs, certificate) do
      certificate |> Ash.Changeset.for_update(:update, attrs) |> Ash.update(authorize?: false)
    end
  end

  def delete_certificate(user, id) do
    with :ok <- editable_award(user, id),
         {:ok, certificate} <- owned(user, id),
         do: Ash.destroy(certificate, authorize?: false)
  end

  defp editable_award(user, id) do
    case JosjobLrn.CourseAwards.owned(user, id) do
      {:ok, _} -> {:error, :certificate_locked}
      _ -> :ok
    end
  end

  defp owned(user, id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         {:ok, %Certificate{user_id: owner} = certificate} <-
           Ash.get(Certificate, id, authorize?: false),
         true <- owner == user.id do
      {:ok, certificate}
    else
      _ -> {:error, :not_found}
    end
  end

  defp attributes(attrs, certificate \\ %Certificate{}) do
    attrs = attrs |> Map.take(@fields) |> Map.new(fn {k, v} -> {k, trim(v)} end)

    with {:ok, issued} <- date(Map.get(attrs, "issued_on", certificate.issued_on)),
         {:ok, expires} <- date(Map.get(attrs, "expires_on", certificate.expires_on)),
         true <- is_nil(issued) or Date.compare(issued, Date.utc_today()) != :gt,
         true <- is_nil(issued) or is_nil(expires) or Date.compare(expires, issued) != :lt,
         true <- safe_url?(Map.get(attrs, "credential_url", certificate.credential_url)) do
      {:ok, Map.merge(attrs, %{"issued_on" => issued, "expires_on" => expires})}
    else
      _ -> {:error, :invalid_certificate}
    end
  end

  defp trim(v) when is_binary(v) do
    case String.trim(v) do
      "" -> nil
      value -> value
    end
  end

  defp trim(v), do: v
  defp date(nil), do: {:ok, nil}
  defp date(%Date{} = value), do: {:ok, value}
  defp date(value) when is_binary(value), do: Date.from_iso8601(value)
  defp date(_), do: {:error, :invalid_date}

  defp safe_url?(nil), do: true

  defp safe_url?(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host, userinfo: nil}}
      when scheme in ["https", "http"] and is_binary(host) and byte_size(host) > 0 ->
        true

      _ ->
        false
    end
  end

  defp safe_url?(_), do: false

  def to_json(c),
    do: %{
      id: c.id,
      title: c.title,
      issuer: c.issuer,
      issued_on: c.issued_on,
      expires_on: c.expires_on,
      credential_id: c.credential_id,
      credential_url: c.credential_url,
      source: "self_reported",
      editable: true,
      recorded_period: nil,
      expired: not is_nil(c.expires_on) and Date.compare(c.expires_on, Date.utc_today()) == :lt
    }

  defp onboarding_certificates(user) do
    profile = Profile |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)
    answers = if profile && is_map(profile.answers), do: profile.answers, else: %{}

    achievements =
      case Map.get(answers, "achievements") do
        values when is_list(values) -> values
        _ -> []
      end

    achievements
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, index} ->
      if is_map(item) and String.downcase(text(item["type"])) == "certification" and
           text(item["name"]) != "" do
        [
          %{
            id: "onboarding-#{index}",
            title: text(item["name"]),
            issuer: text(item["issuer"]),
            source: "onboarding",
            editable: false,
            issued_on: nil,
            expires_on: nil,
            credential_id: nil,
            credential_url: nil,
            expired: false,
            recorded_period:
              [period(item["from"]), period(item["to"])]
              |> Enum.reject(&is_nil/1)
              |> Enum.join(" – ")
          }
        ]
      else
        []
      end
    end)
  end

  defp text(value) when is_binary(value), do: String.trim(value)
  defp text(_), do: ""

  defp period(%{"year" => year} = value) when is_integer(year) and year in 1900..2100 do
    case value["month"] do
      month when is_integer(month) and month in 1..12 ->
        "#{year}-#{String.pad_leading(to_string(month), 2, "0")}"

      _ ->
        to_string(year)
    end
  end

  defp period(_), do: nil
end
