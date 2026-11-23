defmodule JosjobRag.CategoryRanking do
  @moduledoc "CV categories and skill matching without embedding or LLM requests."

  alias JosjobRag.Text

  @version 1
  # Local role tags use explicit role names and specific skills. Generic skills
  # such as communication, Git and SQL alone do not establish a profession.
  @roles [
    {"backend", "software", ~w(backend back-end),
     ["Elixir", "Phoenix", "Go", "Java", "Node.js", "Django", "Spring", "Ruby", "Rails"]},
    {"frontend", "software", ~w(frontend front-end),
     ["JavaScript", "TypeScript", "React", "Vue", "Angular", "HTML", "CSS"]},
    {"full_stack", "software",
     ["full stack", "full-stack", "software engineer", "software developer"], []},
    {"mobile", "software", ["mobile developer", "android developer", "ios developer"],
     ["Flutter", "Dart", "Swift", "Kotlin", "React Native"]},
    {"data", "software", ["data analyst", "data scientist", "data engineer", "machine learning"],
     ["Python", "Pandas", "NumPy", "Tableau", "Power BI", "Machine Learning"]},
    {"infrastructure", "software",
     ["devops", "site reliability", "cloud engineer", "system administrator"],
     ["Kubernetes", "Docker", "Terraform", "Linux", "AWS"]},
    {"design", "creative", ["designer", "ui design", "ux research", "graphic design"],
     [
       "Figma",
       "UI Design",
       "UX Research",
       "Prototyping",
       "Graphic Design",
       "Photoshop",
       "Illustrator"
     ]},
    {"marketing", "commercial", ["marketing", "content writer", "copywriter"],
     ["SEO", "Copywriting", "Digital Marketing", "Google Ads", "Social Media Marketing"]},
    {"sales", "commercial", ["sales", "business development", "account executive"],
     ["Sales", "Lead Generation", "Sales Negotiation"]},
    {"finance", "business", ["accountant", "accounting", "finance", "bookkeeper"],
     ["Accounting", "Bookkeeping", "Financial Analysis", "Taxation"]},
    {"people", "business", ["human resources", "recruiter", "recruitment"],
     ["Recruitment", "Human Resources", "Payroll"]},
    {"support", "service", ["customer support", "customer service", "call center"],
     ["Customer Service", "Customer Support", "Ticket Management"]},
    {"hospitality", "service", ["barista", "chef", "waiter", "housekeeping", "hospitality"],
     ["Barista Skills", "Food Preparation", "Housekeeping", "Food Safety"]},
    {"logistics", "operations", ["warehouse", "logistics", "driver", "supply chain"],
     ["Warehouse Management", "Forklift Operation", "Route Planning", "Freight Handling"]},
    {"healthcare", "healthcare", ["nurse", "nursing", "doctor", "pharmacist", "healthcare"],
     ["Nursing", "Patient Care", "Pharmacy"]},
    {"education", "education", ["teacher", "tutor", "lecturer", "instructor"],
     ["Teaching", "Lesson Planning", "Classroom Management"]}
  ]

  def profile(cv) do
    hash = :crypto.hash(:sha256, Text.cv_text(cv)) |> Base.encode16(case: :lower)
    cached = get(cv, :matching_profile)

    if is_map(cached) and get(cached, :version) == @version and get(cached, :content_hash) == hash do
      cached
    else
      skills = Text.requirement_list(get(cv, :skills))

      titles =
        cv
        |> get(:experience)
        |> List.wrap()
        |> Enum.map(&get(&1, :title))
        |> Enum.filter(&is_binary/1)
        |> Enum.join(" ")

      %{
        "version" => @version,
        "content_hash" => hash,
        "skills" => skills,
        "categories" => classify(titles, skills),
        "method" => "category_skill"
      }
    end
  end

  def categories(job) do
    title = get(job, :title) || ""
    explicit_roles = classify(title, [])

    if explicit_roles == [],
      do: classify(title, Text.requirement_list(get(job, :requirements))),
      else: explicit_roles
  end

  def rank(cv_or_profile, jobs, opts \\ []) do
    profile =
      if get(cv_or_profile, :method) == "category_skill",
        do: cv_or_profile,
        else: profile(cv_or_profile)

    cv_categories = get(profile, :categories) || []
    skills = get(profile, :skills) || []
    now = opts[:now] || DateTime.utc_now()

    jobs
    |> Enum.map(fn job ->
      categories = categories(job)
      bucket = bucket(cv_categories, categories)
      requirements = Text.requirement_list(get(job, :requirements))
      # Detailed skill comparison is only needed for plausible/unknown roles.
      {matched, missing} =
        if bucket == 3, do: {[], []}, else: Text.split_skills(requirements, skills)

      skill = if requirements == [], do: 0.0, else: length(matched) / length(requirements)

      label =
        case bucket do
          0 -> "Relevant category"
          1 -> "Related category"
          2 -> if(matched == [], do: "Not enough information", else: "Skill overlap")
          3 -> "Less relevant"
        end

      explanation =
        if bucket == 3 do
          "Less relevant: this role is outside your CV categories. Its skill fit has not been assessed."
        else
          "#{label}. #{length(matched)} of #{length(requirements)} required skills found in your CV."
        end

      %{
        job_id: get(job, :id),
        job: job,
        categories: categories,
        category_bucket: bucket,
        relevance_label: label,
        match_score: Float.round((3 - bucket + skill) / 4, 4),
        match: Float.round(skill, 4),
        semantic_score: nil,
        skill_score: if(bucket == 3 or requirements == [], do: nil, else: Float.round(skill, 4)),
        recency_score: JosjobRag.Ranker.recency_score(get(job, :posted_at), now),
        matched_skills: matched,
        missing_skills: missing,
        explanation: explanation,
        course: nil
      }
    end)
    |> Enum.sort_by(
      &{&1.category_bucket, -(&1.skill_score || 0.0), -&1.recency_score, to_string(&1.job_id)}
    )
    |> then(fn items ->
      if is_integer(opts[:limit]), do: Enum.take(items, opts[:limit]), else: items
    end)
  end

  def list(user, cv, params) do
    if params["scope"] == "manage" do
      {:error,
       {:invalid_params, %{"sort" => "CV relevance is available for public job browsing"}}}
    else
      with {:ok, candidates} <-
             JosjobJob.Listings.candidates(user, Map.put(params, "sort", "newest")) do
        ranked = rank(profile(cv), candidates.jobs)
        filters = candidates.filters
        page = Enum.slice(ranked, (filters.page - 1) * filters.page_size, filters.page_size)

        {:ok,
         %{
           jobs: Enum.map(page, & &1.job),
           organizations: candidates.organizations,
           relevance:
             Map.new(
               page,
               &{&1.job_id,
                Map.take(&1, [
                  :relevance_label,
                  :categories,
                  :matched_skills,
                  :missing_skills,
                  :skill_score,
                  :explanation
                ])}
             ),
           meta: %{
             page: filters.page,
             page_size: filters.page_size,
             total: length(ranked),
             total_pages: ceil(length(ranked) / filters.page_size),
             relevance_status: "ready",
             cv_id: get(cv, :cv_id),
             cv_categories: get(profile(cv), :categories),
             method: "category_skill"
           }
         }}
      end
    end
  end

  defp classify(title, skills) do
    title = Text.normalize(title)

    for {id, _family, names, anchors} <- @roles,
        Enum.any?(names, &phrase?(title, &1)) or
          Enum.any?(anchors, fn anchor -> Enum.any?(skills, &Text.same_skill?(&1, anchor)) end),
        do: id
  end

  defp phrase?(text, phrase),
    do: Regex.match?(~r/(?:^|[^a-z0-9])#{Regex.escape(phrase)}(?:$|[^a-z0-9])/u, text)

  defp bucket([], _), do: 2
  defp bucket(_, []), do: 2

  defp bucket(cv, job) do
    cond do
      Enum.any?(cv, &(&1 in job)) -> 0
      Enum.any?(cv, fn left -> Enum.any?(job, &(family(left) == family(&1))) end) -> 1
      true -> 3
    end
  end

  defp family(id),
    do: Enum.find_value(@roles, id, fn {key, family, _, _} -> if key == id, do: family end)

  defp get(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp get(_, _), do: nil
end
