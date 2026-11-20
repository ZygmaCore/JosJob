defmodule JosjobRagpdf.Result do
  @moduledoc """
  Normalizes untrusted extraction payloads into the one result shape the HTTP
  API exposes.

  Provider responses (and LLM JSON in particular) may use string or atom keys,
  omit fields, add unknown fields, or return the wrong type. `normalize/1`
  always produces string keys and JSON-safe values:

      %{
        "skills" => [%{"name" => "Elixir", "confidence" => 0.9, "source" => "gemini"}],
        "experience" => [...],
        "education" => [...],
        "extraction_confidence" => 0.82
      }

  Skills without a usable name and records where every field is blank are
  dropped.
  """

  @type t :: %{required(String.t()) => term()}
  @type record :: %{required(String.t()) => String.t() | nil}

  @experience_fields [:title, :company, :start_date, :end_date, :description]
  @education_fields [:degree, :institution, :field, :start_date, :end_date]

  @doc "The empty normalized result."
  @spec empty() :: t()
  def empty do
    %{
      "skills" => [],
      "experience" => [],
      "education" => [],
      "extraction_confidence" => 0.0
    }
  end

  @doc "Normalize any provider payload into the canonical result map."
  @spec normalize(term()) :: t()
  def normalize(map) when is_map(map) do
    %{
      "skills" => normalize_skills(fetch(map, :skills)),
      "experience" => normalize_records(fetch(map, :experience), @experience_fields),
      "education" => normalize_records(fetch(map, :education), @education_fields),
      "extraction_confidence" => normalize_confidence(fetch(map, :extraction_confidence))
    }
  end

  def normalize(_other), do: empty()

  @doc """
  True when the result contains no usable skills, experience or education.

  Values are normalized first, so arrays that only contain malformed entries
  also count as empty.
  """
  @spec empty?(term()) :: boolean()
  def empty?(result) do
    normalized = normalize(result)

    normalized["skills"] == [] and normalized["experience"] == [] and
      normalized["education"] == []
  end

  # -- skills -----------------------------------------------------------------

  defp normalize_skills(entries) do
    entries
    |> as_list()
    |> Enum.flat_map(fn entry ->
      case normalize_skill(entry) do
        nil -> []
        skill -> [skill]
      end
    end)
  end

  defp normalize_skill(entry) when is_map(entry) do
    case normalize_text(fetch(entry, :name)) do
      nil ->
        nil

      name ->
        skill = %{
          "name" => name,
          "confidence" => normalize_confidence(fetch(entry, :confidence))
        }

        case normalize_text(fetch(entry, :source)) do
          nil -> skill
          source -> Map.put(skill, "source", source)
        end
    end
  end

  defp normalize_skill(_entry), do: nil

  # -- experience / education -------------------------------------------------

  defp normalize_records(entries, fields) do
    entries
    |> as_list()
    |> Enum.flat_map(fn entry ->
      case normalize_record(entry, fields) do
        nil -> []
        record -> [record]
      end
    end)
  end

  defp normalize_record(entry, fields) when is_map(entry) do
    record =
      Map.new(fields, fn field ->
        {Atom.to_string(field), normalize_text(fetch(entry, field))}
      end)

    if Enum.all?(fields, fn field -> is_nil(Map.get(record, Atom.to_string(field))) end) do
      nil
    else
      record
    end
  end

  defp normalize_record(_entry, _fields), do: nil

  # -- value normalization ----------------------------------------------------

  defp normalize_confidence(value) do
    case to_number(value) do
      nil ->
        0.0

      number ->
        clamped = number |> max(0.0) |> min(1.0)
        clamped * 1.0
    end
  end

  defp to_number(value) when is_integer(value), do: value * 1.0
  defp to_number(value) when is_float(value), do: value

  defp to_number(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} -> number
      _other -> nil
    end
  end

  defp to_number(_value), do: nil

  defp normalize_text(nil), do: nil

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value) when is_boolean(value), do: nil

  defp normalize_text(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_text()

  defp normalize_text(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_text(_value), do: nil

  defp as_list(list) when is_list(list), do: list
  defp as_list(_other), do: []

  defp fetch(map, key) when is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end
end
