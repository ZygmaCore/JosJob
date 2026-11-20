defmodule JosjobRagpdf.Providers.Keyword do
  @moduledoc """
  Offline provider that matches known skills against plain text.

  It is the last fallback in the chain: no network, no API key, low
  confidence. Matching is case-insensitive on word boundaries, so `"Java"`
  does not match `"JavaScript"`. Regex metacharacters in skill names are
  escaped.

  Unknown skills are capped at 50. When no skill matches, an empty result is
  returned successfully — the worker decides whether that is `:partial` or
  `:unreadable`.
  """

  @behaviour JosjobRagpdf.Provider

  @confidence 0.2
  @max_skills 50

  @impl true
  def extract_pdf(path, opts \\ []) when is_binary(path) do
    case JosjobRagpdf.Pdf.text(path) do
      {:ok, text} -> extract_text(text, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def extract_text(text, opts \\ []) when is_binary(text) do
    text = JosjobRagpdf.Prompt.sanitize_text(text)

    if String.trim(text) == "" do
      {:error, :no_text}
    else
      skills = matching_skills(text, known_skill_names(opts))

      result = %{
        "skills" => skills,
        "experience" => [],
        "education" => [],
        "extraction_confidence" => if(skills == [], do: 0.0, else: @confidence)
      }

      {:ok, result, %{provider: "keyword", model: nil, usage: nil}}
    end
  end

  defp known_skill_names(opts) do
    case opts[:known_skills] do
      skills when is_list(skills) -> JosjobRagpdf.Prompt.known_skill_names(skills)
      _other -> []
    end
  end

  defp matching_skills(text, names) do
    names
    |> Enum.filter(&present?(&1, text))
    |> Enum.map(fn name ->
      %{"name" => name, "confidence" => @confidence, "source" => "keyword"}
    end)
    |> Enum.take(@max_skills)
  end

  defp present?(name, text) do
    case compile(name) do
      {:ok, regex} -> Regex.match?(regex, text)
      {:error, _reason} -> false
    end
  end

  defp compile(name) do
    escaped = Regex.escape(name)

    pattern =
      boundary(String.first(name)) <>
        escaped <>
        boundary(String.last(name))

    Regex.compile(pattern, "iu")
  rescue
    _exception -> {:error, :invalid_pattern}
  end

  # `\b` only makes sense next to a word character. For names such as "C++"
  # the boundary is applied on the side that starts/ends with a word char.
  defp boundary(nil), do: ""

  defp boundary(char) do
    if word_char?(char), do: "\\b", else: ""
  end

  defp word_char?(char) do
    Regex.match?(~r/^[\p{L}\p{N}_]$/u, char)
  end
end
