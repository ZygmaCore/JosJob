defmodule JosjobRagpdf.MergeTest do
  use ExUnit.Case, async: true

  alias JosjobRagpdf.Merge

  defp empty_result do
    %{
      "skills" => [],
      "experience" => [],
      "education" => [],
      "extraction_confidence" => 0.0
    }
  end

  describe "merge/1" do
    test "returns the empty shape for an empty list or non-list input" do
      assert Merge.merge([]) == empty_result()
      assert Merge.merge(nil) == empty_result()
    end

    test "returns the empty shape when every chunk is empty" do
      assert Merge.merge([%{}, %{}, %{skills: []}]) == empty_result()
    end

    test "normalizes atom-keyed and string-keyed chunks" do
      result =
        Merge.merge([
          %{skills: [%{name: "Elixir", confidence: 0.8}], extraction_confidence: 0.8},
          %{
            "skills" => [%{"name" => "elixir", "confidence" => 0.6}],
            "extraction_confidence" => 0.6
          }
        ])

      assert result["skills"] == [%{"name" => "Elixir", "confidence" => 0.8}]
      assert result["extraction_confidence"] == 0.7
    end

    test "dedupes skills case-insensitively, keeping the highest confidence and its source" do
      result =
        Merge.merge([
          %{
            "skills" => [
              %{"name" => "Elixir", "confidence" => 0.4, "source" => "keyword"}
            ]
          },
          %{
            "skills" => [
              %{"name" => "  elixir ", "confidence" => 0.9, "source" => "gemini"}
            ]
          },
          %{
            "skills" => [
              %{"name" => "ELIXIR", "confidence" => 0.2, "source" => "nine_router"}
            ]
          }
        ])

      assert result["skills"] == [
               %{"name" => "elixir", "confidence" => 0.9, "source" => "gemini"}
             ]
    end

    test "keeps a source from an equal-confidence duplicate when the winner has none" do
      result =
        Merge.merge([
          %{"skills" => [%{"name" => "SQL", "confidence" => 0.5}]},
          %{"skills" => [%{"name" => "sql", "confidence" => 0.5, "source" => "gemini"}]}
        ])

      assert result["skills"] == [
               %{"name" => "SQL", "confidence" => 0.5, "source" => "gemini"}
             ]
    end

    test "sorts skills by confidence descending, then name ascending ignoring case" do
      result =
        Merge.merge([
          %{
            "skills" => [
              %{"name" => "Beta", "confidence" => 0.5},
              %{"name" => "alpha", "confidence" => 0.5},
              %{"name" => "Gamma", "confidence" => 0.9},
              %{"name" => "Delta", "confidence" => 0.1}
            ]
          }
        ])

      assert Enum.map(result["skills"], & &1["name"]) == ["Gamma", "alpha", "Beta", "Delta"]
    end

    test "dedupes experience by normalized title/company/start_date and keeps the longer description" do
      result =
        Merge.merge([
          %{
            "experience" => [
              %{
                "title" => "Senior Engineer",
                "company" => "Acme",
                "start_date" => "2024-01",
                "end_date" => nil,
                "description" => "Short"
              }
            ]
          },
          %{
            "experience" => [
              %{
                "title" => " senior  engineer ",
                "company" => "ACME",
                "start_date" => "2024-01",
                "end_date" => "2025-06",
                "description" => "A much longer description of the work"
              }
            ]
          }
        ])

      assert [experience] = result["experience"]
      assert experience["title"] == "Senior Engineer"
      assert experience["company"] == "Acme"
      assert experience["start_date"] == "2024-01"
      assert experience["end_date"] == "2025-06"
      assert experience["description"] == "A much longer description of the work"
    end

    test "keeps distinct experience records apart and sorts dates descending with nils last" do
      result =
        Merge.merge([
          %{
            "experience" => [
              %{"title" => "Old", "company" => "Acme", "start_date" => "2020-01"},
              %{"title" => "No date", "company" => "Acme"},
              %{"title" => "B role", "company" => "Acme", "start_date" => "2024-01"},
              %{"title" => "A role", "company" => "Acme", "start_date" => "2024-01"}
            ]
          }
        ])

      assert Enum.map(result["experience"], & &1["title"]) == [
               "A role",
               "B role",
               "Old",
               "No date"
             ]
    end

    test "dedupes education by normalized degree/institution/start_date and fills blank fields" do
      result =
        Merge.merge([
          %{
            "education" => [
              %{
                "degree" => "BSc",
                "institution" => "MIT",
                "start_date" => "2016-09",
                "field" => nil,
                "end_date" => nil
              }
            ]
          },
          %{
            "education" => [
              %{
                "degree" => " bsc ",
                "institution" => "mit",
                "start_date" => "2016-09",
                "field" => "Computer Science",
                "end_date" => "2020-06"
              }
            ]
          }
        ])

      assert [education] = result["education"]
      assert education["degree"] == "BSc"
      assert education["institution"] == "MIT"
      assert education["field"] == "Computer Science"
      assert education["end_date"] == "2020-06"
    end

    test "sorts education by start_date descending, then degree ascending" do
      result =
        Merge.merge([
          %{
            "education" => [
              %{"degree" => "MSc", "institution" => "MIT", "start_date" => "2024-01"},
              %{"degree" => "BSc", "institution" => "MIT", "start_date" => "2024-01"},
              %{"degree" => "MBA", "institution" => "MIT", "start_date" => "2018-01"},
              %{"degree" => "Cert", "institution" => "MIT"}
            ]
          }
        ])

      assert Enum.map(result["education"], & &1["degree"]) == ["BSc", "MSc", "MBA", "Cert"]
    end

    test "averages numeric chunk confidences and rounds to four decimals" do
      result =
        Merge.merge([
          %{"extraction_confidence" => 0.8},
          %{"extraction_confidence" => 0.6},
          %{"extraction_confidence" => 0.33333}
        ])

      assert result["extraction_confidence"] == 0.5778
    end

    test "ignores missing, nil and non-numeric confidences" do
      result =
        Merge.merge([
          %{"extraction_confidence" => 0.5},
          %{},
          %{"extraction_confidence" => nil},
          %{"extraction_confidence" => "0.9"},
          %{"extraction_confidence" => 0.5}
        ])

      assert result["extraction_confidence"] == 0.5
    end

    test "clamps out-of-range confidences before averaging" do
      result =
        Merge.merge([
          %{"extraction_confidence" => 1.5},
          %{"extraction_confidence" => 0.5}
        ])

      assert result["extraction_confidence"] == 0.75
    end

    test "returns 0.0 when no chunk has a numeric confidence" do
      result = Merge.merge([%{"skills" => [%{"name" => "Elixir"}]}, %{}])

      assert result["extraction_confidence"] == 0.0
    end
  end
end
