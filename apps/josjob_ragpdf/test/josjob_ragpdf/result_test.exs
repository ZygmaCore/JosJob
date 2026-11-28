defmodule JosjobRagpdf.ResultTest do
  use ExUnit.Case, async: true

  alias JosjobRagpdf.Result

  defp empty_result do
    %{
      "skills" => [],
      "experience" => [],
      "education" => [],
      "extraction_confidence" => 0.0
    }
  end

  describe "normalize/1" do
    test "returns the empty shape for nil, other non-maps and empty maps" do
      assert Result.normalize(nil) == empty_result()
      assert Result.normalize("not a map") == empty_result()
      assert Result.normalize([%{"name" => "Elixir"}]) == empty_result()
      assert Result.normalize(%{}) == empty_result()
    end

    test "accepts string keys, trims values and drops unknown fields" do
      raw = %{
        "skills" => [
          %{
            "name" => "  Elixir ",
            "confidence" => 0.9,
            "source" => " gemini ",
            "unknown" => "dropped"
          }
        ],
        "experience" => [
          %{
            "title" => " Engineer ",
            "company" => " Acme ",
            "start_date" => "2024-01",
            "end_date" => "",
            "description" => " Built things ",
            "salary" => "nope"
          }
        ],
        "education" => [
          %{
            "degree" => " BSc ",
            "institution" => " MIT ",
            "field" => "CS",
            "start_date" => "2016-09",
            "end_date" => "2020-06",
            "gpa" => 4.0
          }
        ],
        "extraction_confidence" => 0.82,
        "unknown" => true
      }

      assert Result.normalize(raw) == %{
               "skills" => [
                 %{"name" => "Elixir", "confidence" => 0.9, "source" => "gemini"}
               ],
               "experience" => [
                 %{
                   "title" => "Engineer",
                   "company" => "Acme",
                   "start_date" => "2024-01",
                   "end_date" => nil,
                   "description" => "Built things"
                 }
               ],
               "education" => [
                 %{
                   "degree" => "BSc",
                   "institution" => "MIT",
                   "field" => "CS",
                   "start_date" => "2016-09",
                   "end_date" => "2020-06"
                 }
               ],
               "extraction_confidence" => 0.82
             }
    end

    test "accepts atom keys" do
      raw = %{
        skills: [%{name: "Elixir", confidence: 0.7, source: :gemini}],
        experience: [%{title: "Dev", company: "Acme", start_date: "2024-01"}],
        education: [%{degree: "BSc", institution: "MIT"}],
        extraction_confidence: 0.7
      }

      assert %{
               "skills" => [
                 %{"name" => "Elixir", "confidence" => 0.7, "source" => "gemini"}
               ],
               "experience" => [%{"title" => "Dev", "company" => "Acme"}],
               "education" => [%{"degree" => "BSc", "institution" => "MIT"}],
               "extraction_confidence" => 0.7
             } = Result.normalize(raw)
    end

    test "clamps confidence to 0.0..1.0 and defaults to 0.0" do
      raw = %{
        skills: [
          %{"name" => "High", "confidence" => 4.2},
          %{"name" => "Low", "confidence" => -1},
          %{"name" => "Missing"},
          %{"name" => "Text", "confidence" => "not a number"}
        ]
      }

      assert %{"skills" => [high, low, missing, text]} = Result.normalize(raw)

      assert high["name"] == "High"
      assert high["confidence"] == 1.0
      assert low["confidence"] == 0.0
      assert missing["confidence"] == 0.0
      assert text["confidence"] == 0.0
    end

    test "parses numeric string confidences" do
      assert %{"skills" => [%{"confidence" => 0.75}]} =
               Result.normalize(%{"skills" => [%{"name" => "Elixir", "confidence" => " 0.75 "}]})
    end

    test "drops skills without a usable name" do
      raw = %{
        "skills" => [
          %{"confidence" => 0.9},
          %{"name" => "   "},
          %{"name" => nil},
          "Elixir",
          %{"name" => " SQL ", "confidence" => 0.4}
        ]
      }

      assert %{"skills" => [%{"name" => "SQL", "confidence" => 0.4}]} = Result.normalize(raw)
    end

    test "drops experience and education entries where every field is blank" do
      raw = %{
        "experience" => [%{}, %{"title" => "  "}, %{"title" => "Dev"}],
        "education" => [%{"degree" => nil, "institution" => ""}, %{"degree" => "BSc"}]
      }

      assert %{"experience" => [%{"title" => "Dev"}], "education" => [%{"degree" => "BSc"}]} =
               Result.normalize(raw)
    end

    test "ignores non-list collections and non-map entries" do
      raw = %{skills: "Elixir", experience: %{"title" => "Dev"}, education: [nil, "BSc"]}

      assert Result.normalize(raw) == empty_result()
    end

    test "coerces numeric date fields to strings" do
      assert %{"experience" => [%{"start_date" => "2024"}]} =
               Result.normalize(%{"experience" => [%{"start_date" => 2024}]})
    end

    test "is idempotent" do
      raw = %{
        "skills" => [%{"name" => "Elixir", "confidence" => 0.9, "source" => "gemini"}],
        "experience" => [%{"title" => "Dev", "start_date" => "2024-01"}],
        "education" => []
      }

      once = Result.normalize(raw)
      assert Result.normalize(once) == once
    end
  end

  describe "empty?/1" do
    test "is true for empty, nil and malformed-only results" do
      assert Result.empty?(nil)
      assert Result.empty?(%{})
      assert Result.empty?(empty_result())
      assert Result.empty?(%{"skills" => [%{"confidence" => 0.9}], "experience" => []})
      assert Result.empty?(%{"skills" => "Elixir", "experience" => nil})
    end

    test "is false when any collection has a usable entry" do
      refute Result.empty?(%{"skills" => [%{"name" => "Elixir"}]})
      refute Result.empty?(%{"experience" => [%{"title" => "Dev"}]})
      refute Result.empty?(%{"education" => [%{"degree" => "BSc"}]})
      refute Result.empty?(%{skills: [%{name: "Elixir"}]})
    end
  end
end
