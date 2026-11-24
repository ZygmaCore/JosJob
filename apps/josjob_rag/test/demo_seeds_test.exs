defmodule JosjobRag.DemoSeedsTest do
  use Josjob.DataCase, async: false
  require Ash.Query
  alias JosjobRag.{DemoSeeds, Analyses, CategoryRanking}
  alias JosjobJob.{Job, CurriculumVitae}
  alias Josjob.Accounts.User

  test "seed creates distinct owned CVs, realistic ordering and repeatable jobs without resetting edits" do
    {:ok, first} = DemoSeeds.seed()
    assert length(first.candidates) == 6
    assert first.jobs == 22
    assert first.active_jobs == 20
    assert length(Enum.uniq_by(first.candidates, & &1.cv_id)) == 6

    definitions = DemoSeeds.manifest()

    for person <- definitions["candidates"] do
      candidate = Enum.find(first.candidates, &(&1.email == person["email"]))
      user = Ash.get!(User, candidate.user_id, authorize?: false)
      assert user.mandatory_completed
      assert Bcrypt.verify_pass(first.initial_password, user.hashed_password)
      {:ok, cv} = Analyses.cv(user)
      assert cv["skills"] == person["skills"]
      assert cv["extraction"]["provider"] == "synthetic_demo"
      assert CurriculumVitae.get_for(user).resume_document.url =~ "/assets/demo-cvs/"
      {:ok, listing} = CategoryRanking.list(user, cv, %{"q" => "CV Demo"})
      expected = Enum.find(definitions["jobs"], &(&1["key"] == person["slug"] <> "-1"))
      assert hd(listing.jobs).title == expected["title"]
      assert listing.meta.total == 20
      other = Enum.find(first.candidates, &(&1.user_id != user.id))
      assert {:error, :not_found} = Analyses.cv(user, other.cv_id)
    end

    [job | _] =
      Job
      |> Ash.Query.filter(organization_id == ^first.organization_id)
      |> Ash.read!(authorize?: false)

    Ash.update!(
      Ash.Changeset.for_update(job, :update, %{description: "Edited demo job - preserve on rerun"}),
      authorize?: false
    )

    [candidate | _] = first.candidates
    user = Ash.get!(User, candidate.user_id, authorize?: false)
    changed_hash = Bcrypt.hash_pwd_salt("ChangedDemoPass123!")

    user
    |> Ash.Changeset.for_update(:update, %{})
    |> Ash.Changeset.force_change_attribute(:hashed_password, changed_hash)
    |> Ash.update!(authorize?: false)

    {:ok, second} = DemoSeeds.seed()
    assert second.organization_id == first.organization_id
    assert Enum.map(second.candidates, & &1.user_id) == Enum.map(first.candidates, & &1.user_id)

    assert 22 ==
             Job
             |> Ash.Query.filter(organization_id == ^first.organization_id)
             |> Ash.count!(authorize?: false)

    assert Ash.get!(Job, job.id, authorize?: false).description ==
             "Edited demo job - preserve on rerun"

    assert Ash.get!(User, user.id, authorize?: false).hashed_password == changed_hash
  end

  test "an account collision aborts without changing an unrelated user" do
    user =
      User
      |> Ash.Changeset.for_create(:register_with_email, %{
        email: "employer@cv-demo.josjob.test",
        full_name: "Unrelated account",
        password: "password123"
      })
      |> Ash.create!(authorize?: false)

    assert_raise RuntimeError, ~r/Refusing to reuse an account/, fn -> DemoSeeds.seed() end
    assert Ash.get!(User, user.id, authorize?: false).full_name == "Unrelated account"

    assert 0 ==
             User
             |> Ash.Query.filter(email == "backend@cv-demo.josjob.test")
             |> Ash.count!(authorize?: false)
  end
end
