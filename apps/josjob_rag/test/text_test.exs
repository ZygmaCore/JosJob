defmodule JosjobRag.TextTest do
  use ExUnit.Case, async: true

  alias JosjobRag.Text

  describe "normalize/1" do
    test "lowercases and collapses whitespace" do
      assert Text.normalize("  Senior   Backend \n Engineer  ") == "senior backend engineer"
    end

    test "folds typographic characters" do
      assert Text.normalize("“Node.js”\u00A0— it’s here") == "\"node.js\" - it's here"
    end

    test "drops control characters" do
      assert Text.normalize("a\u0000b\u001Fc") == "a b c"
    end

    test "returns an empty string for non-binary input" do
      assert Text.normalize(nil) == ""
      assert Text.normalize(42) == ""
    end
  end

  describe "tokens/1" do
    test "removes stopwords and de-duplicates while preserving order" do
      assert Text.tokens("We are building the API and the API is fast") ==
               ["building", "api", "fast"]
    end

    test "keeps technical punctuation" do
      tokens = Text.tokens("C++ C# Node.js PostgreSQL")
      assert "c++" in tokens
      assert "c#" in tokens
      assert "node.js" in tokens
      assert "postgresql" in tokens
    end

    test "removes Indonesian stopwords too" do
      assert Text.tokens("saya adalah engineer yang membangun sistem") ==
               ["engineer", "membangun", "sistem"]
    end

    test "returns an empty list for non-binary input" do
      assert Text.tokens(nil) == []
    end
  end

  describe "canonical_skill/1 and same_skill?/2" do
    test "strips version suffixes" do
      assert Text.canonical_skill("Postgres 15") == "postgresql"
      assert Text.canonical_skill("Node.js 20") == "node.js"
    end

    test "folds aliases" do
      assert Text.canonical_skill("JS") == "javascript"
      assert Text.canonical_skill("k8s") == "kubernetes"
      assert Text.canonical_skill("Golang") == "go"
    end

    test "matches aliases but not substrings" do
      assert Text.same_skill?("JS", "JavaScript")
      assert Text.same_skill?("postgres", "PostgreSQL")
      refute Text.same_skill?("Java", "JavaScript")
      refute Text.same_skill?("API", "REST API graphql")
    end

    test "multi-token subsets match" do
      assert Text.same_skill?("REST API", "REST API GraphQL")
    end

    test "empty labels never match" do
      refute Text.same_skill?("", "")
      refute Text.same_skill?(nil, "go")
    end
  end

  describe "split_skills/2" do
    test "keeps original requirement labels" do
      assert Text.split_skills(["Postgres", "React", "Kubernetes"], ["postgresql", "reactjs"]) ==
               {["Postgres", "React"], ["Kubernetes"]}
    end

    test "handles maps and nil" do
      assert Text.split_skills([%{name: "Go"}], ["golang"]) == {["Go"], []}
      assert Text.split_skills(nil, ["go"]) == {[], []}
    end
  end

  describe "requirement_list/1" do
    test "accepts strings and maps and de-duplicates by canonical form" do
      assert Text.requirement_list(["JS", %{name: "JavaScript"}, "  ", "Go"]) ==
               ["JS", "Go"]
    end

    test "returns an empty list for non-lists" do
      assert Text.requirement_list("Go") == []
      assert Text.requirement_list(nil) == []
    end
  end

  describe "text builders" do
    test "job_text accepts atom and string keys and repeats requirements" do
      job = %{
        title: "Backend Engineer",
        industry: "Technology",
        description: "Build APIs",
        requirements: ["Go", "PostgreSQL"]
      }

      text = Text.job_text(job)
      assert text =~ "Backend Engineer"
      assert text =~ "Build APIs"
      assert text =~ "Go, PostgreSQL"
      assert length(String.split(text, "Go, PostgreSQL")) == 3
    end

    test "job_text returns an empty string for non-maps" do
      assert Text.job_text(nil) == ""
    end

    test "course_text includes industries and the section title" do
      course = %{
        "title" => "Backend Bootcamp",
        "description" => "Learn APIs",
        "industries" => [%{name: "Technology"}],
        "section" => %{title: "Engineering"}
      }

      text = Text.course_text(course)
      assert text =~ "Backend Bootcamp"
      assert text =~ "Learn APIs"
      assert text =~ "Technology"
      assert text =~ "Engineering"
    end

    test "cv_text includes skills, experience, and education" do
      cv = %{
        "skills" => [%{name: "Go"}, "PostgreSQL"],
        "experience" => [%{title: "Backend Engineer", company: "Acme", description: "APIs"}],
        "education" => [%{degree: "BSc", institution: "University", field: "Computer Science"}]
      }

      text = Text.cv_text(cv)
      assert text =~ "Go, PostgreSQL"
      assert text =~ "Backend Engineer at Acme"
      assert text =~ "BSc, University, Computer Science"
    end

    test "cv_text ignores empty entries" do
      assert Text.cv_text(%{skills: [], experience: [], education: []}) == ""
    end
  end
end
