defmodule JosjobRagpdf.Merge do
  @moduledoc """
  Merges the per-chunk extraction results of one CV into a single normalized
  result.

  Chunks overlap and separate providers see the same record with different
  casing, spacing and completeness, so deduplication is fuzzy:

    * skills key on the lowercased name, keeping the highest confidence
    * experience keys on `{title, company, start_date}`, keeping the longest
      description and filling blank fields from duplicates
    * education keys on `{degree, institution, start_date}`

  The merged `extraction_confidence` is the average of the numeric per-chunk
  confidences, rounded to four decimals.
  """

  alias JosjobRagpdf.Result

  @spec merge([map()]) :: Result.t()
  def merge(chunks) when is_list(chunks) do
    normalized = Enum.map(chunks, &Result.normalize/1)

    %{
      "skills" => normalized |> Enum.flat_map(& &1["skills"]) |> merge_skills(),
      "experience" =>
        normalized
        |> Enum.flat_map(& &1["experience"])
        |> merge_records(
          [:title, :company, :start_date],
          :description,
          :title
        ),
      "education" =>
        normalized
        |> Enum.flat_map(& &1["education"])
        |> merge_records(
          [:degree, :institution, :start_date],
          nil,
          :degree
        ),
      "extraction_confidence" => average_confidence(chunks)
    }
  end

  def merge(_other), do: Result.empty()

  # -- skills -----------------------------------------------------------------

  defp merge_skills(skills) do
    skills
    |> Enum.reduce(%{}, fn skill, acc ->
      key = normalize_key(skill["name"])

      case Map.fetch(acc, key) do
        :error -> Map.put(acc, key, skill)
        {:ok, current} -> Map.put(acc, key, better_skill(current, skill))
      end
    end)
    |> Map.values()
    |> Enum.sort_by(fn skill ->
      {-skill["confidence"], normalize_key(skill["name"])}
    end)
  end

  defp better_skill(current, candidate) do
    cond do
      candidate["confidence"] > current["confidence"] ->
        candidate

      candidate["confidence"] < current["confidence"] ->
        current

      true ->
        # Same confidence: keep the first spelling but do not lose a source.
        if is_nil(current["source"]) and not is_nil(candidate["source"]) do
          Map.put(current, "source", candidate["source"])
        else
          current
        end
    end
  end

  # -- experience / education -------------------------------------------------

  defp merge_records(records, key_fields, longer_field, tie_field) do
    records
    |> Enum.reduce(%{}, fn record, acc ->
      key = record_key(record, key_fields)

      case Map.fetch(acc, key) do
        :error ->
          Map.put(acc, key, record)

        {:ok, current} ->
          Map.put(acc, key, combine_record(current, record, longer_field))
      end
    end)
    |> Map.values()
    |> Enum.sort(&record_before?(&1, &2, :start_date, tie_field))
  end

  defp record_key(record, fields) do
    fields
    |> Enum.map(fn field -> normalize_key(Map.get(record, Atom.to_string(field))) end)
    |> List.to_tuple()
  end

  defp combine_record(current, duplicate, longer_field) do
    longer_field = if longer_field, do: Atom.to_string(longer_field)

    Enum.reduce(current, current, fn {field, current_value}, acc ->
      duplicate_value = Map.get(duplicate, field)

      value =
        cond do
          field == longer_field -> longer_string(current_value, duplicate_value)
          is_nil(current_value) -> duplicate_value
          true -> current_value
        end

      Map.put(acc, field, value)
    end)
  end

  defp longer_string(nil, other), do: other
  defp longer_string(current, nil), do: current

  defp longer_string(current, duplicate) do
    if String.length(current) >= String.length(duplicate), do: current, else: duplicate
  end

  defp record_before?(left, right, date_field, tie_field) do
    left_date = Map.get(left, Atom.to_string(date_field))
    right_date = Map.get(right, Atom.to_string(date_field))

    cond do
      is_nil(left_date) and is_nil(right_date) -> tie_before?(left, right, tie_field)
      is_nil(left_date) -> false
      is_nil(right_date) -> true
      left_date > right_date -> true
      left_date < right_date -> false
      true -> tie_before?(left, right, tie_field)
    end
  end

  defp tie_before?(left, right, field) do
    key = Atom.to_string(field)

    normalize_key(Map.get(left, key)) <= normalize_key(Map.get(right, key))
  end

  # -- confidence -------------------------------------------------------------

  defp average_confidence([]), do: 0.0

  defp average_confidence(chunks) do
    values =
      chunks
      |> Enum.map(&chunk_confidence/1)
      |> Enum.reject(&is_nil/1)

    case values do
      [] -> 0.0
      values -> Float.round(Enum.sum(values) / length(values), 4)
    end
  end

  defp chunk_confidence(chunk) when is_map(chunk) do
    case fetch(chunk, :extraction_confidence) do
      value when is_number(value) ->
        clamped = value |> max(0.0) |> min(1.0)
        clamped * 1.0

      _other ->
        nil
    end
  end

  defp chunk_confidence(_chunk), do: nil

  # -- shared -----------------------------------------------------------------

  defp normalize_key(nil), do: ""

  defp normalize_key(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.split()
    |> Enum.join(" ")
  end

  defp normalize_key(value), do: value |> to_string() |> normalize_key()

  defp fetch(map, key) when is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end
end
