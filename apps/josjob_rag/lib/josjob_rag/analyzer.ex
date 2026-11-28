defmodule JosjobRag.Analyzer do
  @moduledoc """
  Rank an extracted CV using saved role categories and local skill overlap.
  Normal analysis never calls embedding or AI providers. The PDF service owns
  the one-time extraction; this module reuses the resulting structured facts.
  Explicit legacy indexing utilities remain separate from job discovery.
  """

  require Logger
  require Ash.Query

  alias JosjobLrn.Learning
  alias JosjobRag.{CategoryRanking, Embeddings, Ranker, Text, VectorStore}
  alias JosjobJob.Listings

  @job_page_size 50
  @max_pages 5
  @default_max_candidates 250
  @default_limit 10

  @doc """
  Analyze a structured CV for a user and return ranked jobs + course links.

  The CV map accepts string or atom keys: `skills`, `experience`, `education`,
  and an optional `cv_id`.
  """
  @spec analyze(term(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze(user, cv, opts \\ []) do
    cv = cv || %{}
    now = opts[:now] || DateTime.utc_now()
    jobs = Keyword.get_lazy(opts, :jobs, fn -> load_jobs(user, opts) end)
    courses = Keyword.get_lazy(opts, :courses, fn -> load_courses(user, opts) end)
    profile = CategoryRanking.profile(cv)
    ranked = CategoryRanking.rank(profile, jobs, limit: opts[:limit] || @default_limit, now: now)
    missing_skills = ranked |> Enum.flat_map(& &1.missing_skills) |> Enum.uniq()
    recommendations = Ranker.recommend_courses(missing_skills, courses)
    {ranked, recommended_courses} = Ranker.attach_courses(ranked, recommendations)

    {:ok,
     %{
       cv_id: cv_id(cv, opts),
       provider: "local",
       model: "category-skill-v1",
       dimensions: nil,
       semantic: false,
       method: "category_skill",
       profile: profile,
       analyzed_at: now,
       scoring: %{
         method: "category_skill",
         order: ["category", "skill_overlap", "recency"],
         external_ai_calls: 0
       },
       jobs: ranked,
       courses: recommended_courses
     }}
  end

  @doc "Embed and store one job (no-op when its text is unchanged)."
  def index_job(job, opts \\ []) when is_map(job) do
    index_items(:job, [job], opts)
  end

  @doc "Embed and store many jobs in one batched call."
  def index_jobs(jobs, opts \\ []) when is_list(jobs), do: index_items(:job, jobs, opts)

  @doc "Embed and store one course (no-op when its text is unchanged)."
  def index_course(course, opts \\ []) when is_map(course),
    do: index_items(:course, [course], opts)

  @doc "Embed and store many courses in one batched call."
  def index_courses(courses, opts \\ []) when is_list(courses),
    do: index_items(:course, courses, opts)

  @doc "Embed and store one CV version under `cv_id`."
  def index_cv(cv, opts \\ []) when is_map(cv) do
    id = cv_id(cv, opts)

    if id in [nil, ""] do
      {:error, :missing_cv_id}
    else
      store = Keyword.get(opts, :vector_store, VectorStore)
      embedder = Keyword.get(opts, :embeddings, Embeddings)
      space = Keyword.get(opts, :space, local_space())
      cv = Map.put(cv, :cv_id, id)

      with {:ok, _space, _vectors} <- ensure_vectors(store, embedder, :cv, [cv], space, opts) do
        :ok
      end
    end
  end

  @doc """
  Re-embed every active job and course.

  `force: true` deletes the configured space first, which is useful after
  switching embedding providers.
  """
  def reindex_all(opts \\ []) do
    store = Keyword.get(opts, :vector_store, VectorStore)
    space = Keyword.get(opts, :space, local_space())

    if opts[:force] do
      _ = store.delete_space(:job, space.provider, space.model)
      _ = store.delete_space(:course, space.provider, space.model)
    end

    jobs = load_all_jobs()
    courses = load_all_courses()

    with {:ok, job_space, job_vectors} <-
           ensure_vectors(
             store,
             Keyword.get(opts, :embeddings, Embeddings),
             :job,
             jobs,
             space,
             opts
           ),
         {:ok, _course_space, course_vectors} <-
           ensure_vectors(
             store,
             Keyword.get(opts, :embeddings, Embeddings),
             :course,
             courses,
             job_space,
             opts
           ) do
      {:ok,
       %{
         jobs: length(jobs),
         job_vectors: map_size(job_vectors),
         courses: length(courses),
         course_vectors: map_size(course_vectors),
         provider: job_space && job_space.provider,
         model: job_space && job_space.model
       }}
    end
  end

  # --- data loading -------------------------------------------------------

  @doc false
  def load_jobs(nil, opts) do
    max = opts[:max_candidates] || @default_max_candidates
    load_all_jobs() |> Enum.take(max)
  end

  def load_jobs(user, opts) do
    max = opts[:max_candidates] || @default_max_candidates
    do_load_jobs(user, 1, max, [])
  end

  defp do_load_jobs(user, page, remaining, acc) when page <= @max_pages do
    size = min(@job_page_size, remaining)

    case Listings.list(user, %{"scope" => "browse", "page" => page, "page_size" => size}) do
      {:ok, %{jobs: jobs, meta: meta}} ->
        acc = acc ++ jobs
        total_pages = meta[:total_pages] || 1

        if jobs == [] or length(jobs) >= remaining or page >= total_pages do
          acc
        else
          do_load_jobs(user, page + 1, remaining - length(jobs), acc)
        end

      error ->
        Logger.warning("Could not load jobs for RAG ranking: #{inspect(error)}")
        acc
    end
  rescue
    exception ->
      Logger.warning("Could not load jobs for RAG ranking: #{Exception.message(exception)}")
      acc
  end

  defp do_load_jobs(_user, _page, _remaining, acc), do: acc

  @doc false
  def load_courses(nil, _opts) do
    load_all_courses()
  end

  def load_courses(user, _opts) do
    Learning.visible_courses(org_ids(user))
  rescue
    exception ->
      Logger.warning("Could not load courses for RAG ranking: #{Exception.message(exception)}")
      []
  end

  defp load_all_jobs do
    JosjobJob.Job
    |> Ash.Query.filter(status == "active")
    |> Ash.Query.load(:organization)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.warning("Could not load jobs for RAG reindex: #{Exception.message(exception)}")
      []
  end

  defp load_all_courses do
    JosjobLrn.Learning.Course
    |> Ash.Query.filter(is_active == true)
    |> Ash.Query.load([:section, :industries, :classes])
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.warning("Could not load courses for RAG reindex: #{Exception.message(exception)}")
      []
  end

  defp org_ids(user) do
    Josjob.Orgs.Membership
    |> Ash.Query.filter(user_id == ^user.id and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.organization_id)
    |> Enum.uniq()
  end

  # --- vectors ------------------------------------------------------------

  defp index_items(owner_type, items, opts) do
    store = Keyword.get(opts, :vector_store, VectorStore)
    embedder = Keyword.get(opts, :embeddings, Embeddings)

    space = Keyword.get(opts, :space, local_space())

    with {:ok, _space, vectors} <-
           ensure_vectors(store, embedder, owner_type, items, space, opts) do
      {:ok, map_size(vectors)}
    end
  end

  defp ensure_vectors(_store, _embedder, _owner_type, [], space, _opts),
    do: {:ok, space, %{}}

  defp ensure_vectors(_store, _embedder, _owner_type, _items, nil, _opts),
    do: {:ok, nil, %{}}

  defp ensure_vectors(store, embedder, owner_type, items, space, opts) do
    text_fun = fn item -> text_for(owner_type, item) end

    items =
      items
      |> Enum.filter(fn item -> not is_nil(owner_id(owner_type, item)) end)

    ids = Enum.map(items, &to_string(owner_id(owner_type, &1)))
    texts = Enum.map(items, text_fun)
    hashes = Enum.map(texts, &VectorStore.content_hash/1)

    case store.hashes(owner_type, ids, space.provider, space.model) do
      {:error, reason} ->
        Logger.warning("Vector store unavailable (#{inspect(reason)}); skipping embeddings")
        {:ok, nil, %{}}

      {:ok, stored_hashes} ->
        pending =
          [items, texts, hashes, ids]
          |> Enum.zip()
          |> Enum.reject(fn {_item, _text, hash, id} -> stored_hashes[id] == hash end)

        case embed_pending(store, embedder, owner_type, pending, space, opts) do
          {:ok, nil, _count} ->
            {:ok, nil, %{}}

          {:ok, actual_space, _count} ->
            case store.vectors(owner_type, ids, actual_space.provider, actual_space.model) do
              {:ok, vectors} ->
                {:ok, actual_space, vectors}

              {:error, reason} ->
                Logger.warning("Could not read stored embeddings: #{inspect(reason)}")
                {:ok, nil, %{}}
            end

          {:error, reason} ->
            Logger.warning("Could not embed/store #{owner_type} texts: #{inspect(reason)}")
            {:ok, nil, %{}}
        end
    end
  end

  defp embed_pending(_store, _embedder, _owner_type, [], space, _opts),
    do: {:ok, space, 0}

  defp embed_pending(store, embedder, owner_type, pending, space, _opts) do
    pending_texts = Enum.map(pending, fn {_item, text, _hash, _id} -> text end)
    provider = Embeddings.module_for(space.provider)

    case embedder.embed_many(pending_texts, provider: provider, dimensions: space.dimensions) do
      {:ok, vectors, actual_space} ->
        rows =
          pending
          |> Enum.zip(vectors)
          |> Enum.map(fn {{_item, text, hash, id}, vector} ->
            %{
              owner_type: owner_type,
              owner_id: id,
              text: text,
              vector: vector,
              provider: actual_space.provider,
              model: actual_space.model,
              content_hash: hash
            }
          end)

        case store.put_many(rows) do
          {:ok, count} ->
            {:ok, actual_space, count}

          {:error, reason} ->
            {:error, {:store_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:embedding_failed, reason}}
    end
  end

  defp local_space,
    do: %{provider: "local", model: "hashed-bow-v1", dimensions: Embeddings.dimensions()}

  defp text_for(:job, item), do: Text.job_text(item)
  defp text_for(:course, item), do: Text.course_text(item)
  defp text_for(:cv, item), do: Text.cv_text(item)

  defp item_id(item) when is_map(item) do
    Map.get(item, :id) || Map.get(item, "id")
  end

  # CV versions are keyed by `cv_id`, which may be an opaque string from the
  # extraction service; jobs and courses use their normal UUID id.
  defp owner_id(:cv, item),
    do: Map.get(item, :cv_id) || Map.get(item, "cv_id") || item_id(item)

  defp owner_id(_owner_type, item), do: item_id(item)

  defp cv_id(cv, opts) do
    opts[:cv_id] || Map.get(cv, :cv_id) || Map.get(cv, "cv_id") || Map.get(cv, :id) ||
      Map.get(cv, "id")
  end
end
