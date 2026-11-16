defmodule JosjobRagpdf.Providers.KeywordTest do
  use ExUnit.Case, async: true

  alias JosjobRagpdf.Providers.Keyword

  describe "extract_text/2 matching" do
    test "matches whole words only" do
      assert {:ok, result, meta} =
               Keyword.extract_text("Worked with Java and JavaScript daily.",
                 known_skills: ["Java"]
               )

      assert [%{"name" => "Java", "confidence" => 0.2, "source" => "keyword"}] =
               result["skills"]

      assert result["extraction_confidence"] == 0.2
      assert result["experience"] == []
      assert result["education"] == []
      assert meta == %{provider: "keyword", model: nil, usage: nil}
    end

    test "is case-insensitive" do
      assert {:ok, result, _meta} =
               Keyword.extract_text("SENIOR elixir ENGINEER", known_skills: ["Elixir"])

      assert [%{"name" => "Elixir"}] = result["skills"]
    end

    test "does not match a skill embedded in a longer word" do
      assert {:ok, result, _meta} =
               Keyword.extract_text("MySQL and PostgreSQL and NoSQL", known_skills: ["SQL"])

      assert result["skills"] == []
      assert result["extraction_confidence"] == 0.0
    end

    test "escapes regex metacharacters in skill names" do
      text = "Built services with C++, C#, Node.js and .NET. Also used (parens)."

      assert {:ok, result, _meta} =
               Keyword.extract_text(text,
                 known_skills: ["C++", "C#", "Node.js", ".NET", "(parens)"]
               )

      assert Enum.map(result["skills"], & &1["name"]) == [
               "C++",
               "C#",
               "Node.js",
               ".NET",
               "(parens)"
             ]
    end

    test "accepts maps with string or atom name keys" do
      assert {:ok, result, _meta} =
               Keyword.extract_text("Elixir and SQL",
                 known_skills: [
                   %{"id" => "1", "name" => "Elixir"},
                   %{name: "SQL"},
                   :not_a_skill,
                   42
                 ]
               )

      assert Enum.map(result["skills"], & &1["name"]) == ["Elixir", "SQL"]
    end

    test "de-duplicates case-insensitively" do
      assert {:ok, result, _meta} =
               Keyword.extract_text("Elixir everywhere",
                 known_skills: ["Elixir", "elixir", %{"name" => "ELIXIR"}]
               )

      assert [%{"name" => "Elixir"}] = result["skills"]
    end

    test "ignores names that do not appear" do
      assert {:ok, result, _meta} =
               Keyword.extract_text("Elixir developer", known_skills: ["Elixir", "Rust"])

      assert Enum.map(result["skills"], & &1["name"]) == ["Elixir"]
    end

    test "caps the result at 50 skills" do
      names = Enum.map(1..60, &"skill#{&1}")
      text = Enum.join(names, " ")

      assert {:ok, result, _meta} = Keyword.extract_text(text, known_skills: names)
      assert length(result["skills"]) == 50
    end

    test "returns an empty successful result when no known skills are given" do
      assert {:ok, result, meta} = Keyword.extract_text("Elixir developer", [])

      assert result == %{
               "skills" => [],
               "experience" => [],
               "education" => [],
               "extraction_confidence" => 0.0
             }

      assert meta == %{provider: "keyword", model: nil, usage: nil}
    end

    test "returns an empty successful result when nothing matches" do
      assert {:ok, result, _meta} =
               Keyword.extract_text("Elixir developer", known_skills: ["Rust", "Go"])

      assert result["skills"] == []
      assert result["extraction_confidence"] == 0.0
    end
  end

  describe "extract_text/2 validation" do
    test "returns :no_text for an empty string" do
      assert {:error, :no_text} = Keyword.extract_text("", known_skills: ["Elixir"])
    end

    test "returns :no_text for whitespace only" do
      assert {:error, :no_text} = Keyword.extract_text("  \n\t ", known_skills: ["Elixir"])
    end

    test "returns :no_text even without known skills" do
      assert {:error, :no_text} = Keyword.extract_text("")
    end

    test "handles invalid UTF-8 without raising" do
      text = <<255, 254, ?E, ?l, ?i, ?x, ?i, ?r>>

      assert {:ok, result, _meta} = Keyword.extract_text(text, known_skills: ["Elixir"])
      assert [%{"name" => "Elixir"}] = result["skills"]
    end
  end

  describe "extract_pdf/2" do
    test "returns an error instead of raising for a missing file" do
      missing = Path.join(System.tmp_dir!(), "josjob_ragpdf-missing-keyword.pdf")

      assert {:error, _reason} = Keyword.extract_pdf(missing, known_skills: ["Elixir"])
    end
  end
end
