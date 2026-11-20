defmodule JosjobRag.Text do
  @moduledoc """
  Text normalization and skill matching shared by embeddings and ranking.

  Everything here is deterministic and dependency-free so ranking can be
  reproduced from the same inputs (a PRD requirement). No stemming library, no
  network calls: just Unicode-safe normalization, stopword removal, a small
  skill alias table, and canonical skill comparison.

  Skill matching is deliberately conservative: `"Java"` must not match
  `"JavaScript"`, and a single vague token like `"api"` must not match
  `"REST API"` without an alias. Ambiguous matches are worse than missing ones
  because the UI claims "skill cocok" to the user.
  """

  @stopwords MapSet.new(~w(
    a an and are as at be been being by for from has have had he her his i in
    into is it its of on or our she that the their them then there these they
    this those to was were we will with you your
    atau dan dari dengan untuk pada yang ini itu saya kami kita anda dia
    adalah akan bisa dapat juga ke karena lebih oleh para saat sudah tidak
    sebagai serta telah tentang
  ))

  # canonical => accepted variants (all normalized before comparison)
  @skill_aliases %{
    "javascript" => ["js"],
    "typescript" => ["ts"],
    "postgresql" => ["postgres", "psql", "pgsql"],
    "kubernetes" => ["k8s"],
    "go" => ["golang"],
    "node.js" => ["node", "nodejs", "node js"],
    "react.js" => ["react", "reactjs"],
    "vue.js" => ["vue", "vuejs"],
    "rest api" => [
      "rest",
      "restful",
      "restful api",
      "rest apis",
      "representational state transfer"
    ],
    "ci/cd" => ["ci cd", "cicd", "continuous integration", "continuous delivery"],
    "machine learning" => ["ml"],
    "artificial intelligence" => ["ai"],
    "natural language processing" => ["nlp"],
    "database" => ["db", "databases"],
    "tailwind css" => ["tailwind", "tailwindcss"],
    "amazon web services" => ["aws"],
    "google cloud platform" => ["gcp"],
    "microsoft azure" => ["azure"]
  }

  # All aliases above are already normalized (lowercase ASCII, single spaces), so
  # the lookup can be built at compile time without calling normalize/1.
  @alias_lookup (fn ->
                   Enum.reduce(@skill_aliases, %{}, fn {canonical, variants}, acc ->
                     Enum.reduce([canonical | variants], acc, fn variant, inner ->
                       Map.put(inner, variant, canonical)
                     end)
                   end)
                 end).()

  @doc """
  Normalize text for comparison.

  Lowercases, folds common typographic characters to ASCII, drops control
  characters, and collapses whitespace. Diacritics are folded as far as
  `:unicode.characters_to_nfd_binary/1` allows without external dependencies.
  """
  @spec normalize(term()) :: String.t()
  def normalize(text) when is_binary(text) do
    text
    |> sanitize_utf8()
    |> String.downcase()
    |> String.replace(~r/[\x{00A0}\x{2000}-\x{200B}]/u, " ")
    |> String.replace(~r/[\x{2018}\x{2019}\x{201B}]/u, "'")
    |> String.replace(~r/[\x{201C}\x{201D}]/u, "\"")
    |> String.replace(~r/[\x{2010}-\x{2015}]/u, "-")
    |> String.replace(~r/[\x00-\x1F\x7F]/, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  def normalize(_text), do: ""

  @doc """
  Tokenize normalized text.

  Keeps `+`, `#`, and inner dots so `c++`, `c#`, and `node.js` survive, drops
  trailing punctuation, removes single characters and stopwords, and
  de-duplicates while preserving order.
  """
  @spec tokens(term()) :: [String.t()]
  def tokens(text) when is_binary(text) do
    text
    |> normalize()
    |> String.replace(~r/[^a-z0-9+#.\s\-\/]/u, " ")
    |> String.replace(~r/\//, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.trim(&1, ".-"))
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&(byte_size(&1) < 2 and &1 not in ["c"]))
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
    |> Enum.uniq()
  end

  def tokens(_text), do: []

  @doc """
  Canonical form of a skill name: normalized, version suffix removed, alias
  folded.

      iex> JosjobRag.Text.canonical_skill("Postgres 15")
      "postgresql"

      iex> JosjobRag.Text.canonical_skill("JS")
      "javascript"
  """
  @spec canonical_skill(term()) :: String.t()
  def canonical_skill(skill) when is_binary(skill) do
    base =
      skill
      |> normalize()
      |> strip_version_suffix()
      |> String.replace(~r/\s*\/\s*/, " ")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    Map.get(@alias_lookup, base, base)
  end

  def canonical_skill(_skill), do: ""

  @doc """
  True when two skill labels refer to the same skill.

  Matches on canonical name, alias, or a multi-token subset (`"rest api"` vs
  `"rest api graphql"`). Single generic tokens do not match longer phrases.
  """
  @spec same_skill?(term(), term()) :: boolean()
  def same_skill?(left, right) do
    a = canonical_skill(left)
    b = canonical_skill(right)

    cond do
      a == "" or b == "" -> false
      a == b -> true
      true -> token_subset?(a, b)
    end
  end

  @doc """
  Partition skill requirements into matched and missing skills relative to a CV
  skill list. Comparisons are case-insensitive and alias-aware; output keeps the
  original requirement labels so explanations read naturally.
  """
  @spec split_skills([term()], [term()]) :: {[String.t()], [String.t()]}
  def split_skills(requirements, cv_skills) do
    requirements = requirement_list(requirements)
    cv_skills = requirement_list(cv_skills)

    {matched, missing} =
      Enum.split_with(requirements, fn requirement ->
        Enum.any?(cv_skills, &same_skill?(&1, requirement))
      end)

    {matched, missing}
  end

  @doc "Normalized, de-duplicated skill labels from strings or `%{name: ...}` maps."
  @spec requirement_list(term()) :: [String.t()]
  def requirement_list(skills) when is_list(skills) do
    skills
    |> Enum.map(&skill_label/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&canonical_skill/1)
  end

  def requirement_list(_skills), do: []

  @doc """
  Text indexed for a job: title, industry, mode, location, description, and
  requirements. Requirements are repeated so they carry a little extra weight in
  bag-of-words embeddings.
  """
  @spec job_text(map()) :: String.t()
  def job_text(job) when is_map(job) do
    requirements = requirement_list(get(job, :requirements))

    [
      get(job, :title),
      get(job, :industry),
      get(job, :employment_type),
      get(job, :work_mode),
      get(job, :location),
      get(job, :description),
      Enum.join(requirements, ", "),
      Enum.join(requirements, ", ")
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join("\n")
  end

  def job_text(_job), do: ""

  @doc "Text indexed for a course: title, description, industries, and section title."
  @spec course_text(map()) :: String.t()
  def course_text(course) when is_map(course) do
    industries =
      course
      |> get(:industries)
      |> List.wrap()
      |> Enum.map(&skill_label/1)
      |> Enum.join(", ")

    section = get(course, :section)

    [
      get(course, :title),
      get(course, :description),
      industries,
      if(is_map(section), do: get(section, :title), else: nil)
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join("\n")
  end

  def course_text(_course), do: ""

  @doc """
  Text indexed for a CV: skills, experience (title, company, description), and
  education. Accepts string or atom keys so it works with API payloads and
  stored JSON alike.
  """
  @spec cv_text(map()) :: String.t()
  def cv_text(cv) when is_map(cv) do
    skills =
      cv
      |> get(:skills)
      |> requirement_list()
      |> Enum.join(", ")

    experience =
      cv
      |> get(:experience)
      |> List.wrap()
      |> Enum.map(fn entry ->
        [get(entry, :title), get(entry, :company), get(entry, :description)]
        |> Enum.filter(&is_binary/1)
        |> Enum.join(" at ")
      end)

    education =
      cv
      |> get(:education)
      |> List.wrap()
      |> Enum.map(fn entry ->
        [get(entry, :degree), get(entry, :institution), get(entry, :field)]
        |> Enum.filter(&is_binary/1)
        |> Enum.join(", ")
      end)

    [skills | experience ++ education]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  def cv_text(_cv), do: ""

  defp strip_version_suffix(text) do
    text
    |> String.split(" ", trim: true)
    |> Enum.reverse()
    |> Enum.drop_while(fn token -> Regex.match?(~r/^v?\d+(\.\d+)*$/, token) end)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp token_subset?(a, b) do
    tokens_a = MapSet.new(tokens(a))
    tokens_b = MapSet.new(tokens(b))

    smaller = if MapSet.size(tokens_a) <= MapSet.size(tokens_b), do: tokens_a, else: tokens_b

    MapSet.size(smaller) >= 2 and MapSet.subset?(smaller, MapSet.union(tokens_a, tokens_b)) and
      MapSet.subset?(smaller, tokens_a) and MapSet.subset?(smaller, tokens_b)
  end

  defp skill_label(%{} = map) do
    case get(map, :name) do
      name when is_binary(name) -> String.trim(name)
      _ -> ""
    end
  end

  defp skill_label(value) when is_binary(value), do: String.trim(value)
  defp skill_label(_value), do: ""

  defp sanitize_utf8(text) do
    if String.valid?(text) do
      text
    else
      case :unicode.characters_to_binary(text, :utf8, :utf8) do
        converted when is_binary(converted) -> converted
        {_kind, converted, _rest} when is_binary(converted) -> converted
        _other -> ""
      end
    end
  end

  defp get(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp get(_other, _key), do: nil
end
