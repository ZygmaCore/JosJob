defmodule Josjob.Repo.Migrations.CreateRagPipeline do
  @moduledoc """
  RAG pipeline storage: pgvector embeddings for jobs/courses/CVs and persisted
  CV ranking results.

  Vectors are 1536-dimensional (`gemini-embedding-2` with
  `outputDimensionality: 1536`; the deterministic local fallback uses the same
  size). Cosine distance uses pgvector's `<=>` operator and an HNSW index.
  """

  use Ecto.Migration

  def up do
    execute("create extension if not exists vector")

    create table(:rag_embeddings, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :owner_type, :text, null: false
      add :owner_id, :text, null: false
      add :provider, :text, null: false
      add :model, :text, null: false
      add :dimensions, :integer, null: false
      add :content_hash, :text, null: false
      add :source_text, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    execute(
      "alter table rag_embeddings add column embedding vector(1536) not null",
      "alter table rag_embeddings drop column embedding"
    )

    create unique_index(:rag_embeddings, [:owner_type, :owner_id, :provider, :model],
             name: :rag_embeddings_owner_space_index
           )

    create index(:rag_embeddings, [:owner_type, :provider, :model])

    execute(
      "create index rag_embeddings_embedding_hnsw_index on rag_embeddings using hnsw (embedding vector_cosine_ops)",
      "drop index if exists rag_embeddings_embedding_hnsw_index"
    )

    create constraint(:rag_embeddings, :rag_embeddings_owner_type_check,
             check: "owner_type IN ('job', 'course', 'cv')"
           )

    create constraint(:rag_embeddings, :rag_embeddings_dimensions_check, check: "dimensions > 0")

    create table(:rag_cv_analyses, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      add :cv_id, :text, null: false
      add :provider, :text
      add :model, :text
      add :cv_text, :text
      add :skills, {:array, :text}, null: false, default: []
      add :payload, :map, null: false, default: %{}
      add :semantic, :boolean, null: false, default: false
      add :analyzed_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:rag_cv_analyses, [:user_id, :cv_id],
             name: :rag_cv_analyses_user_cv_index
           )

    create table(:rag_job_matches, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :analysis_id, references(:rag_cv_analyses, type: :uuid, on_delete: :delete_all),
        null: false

      add :job_id, references(:jobs, type: :uuid, on_delete: :delete_all), null: false
      add :rank_position, :integer, null: false
      add :match_score, :float, null: false
      add :match, :float, null: false
      add :semantic_score, :float
      add :skill_score, :float
      add :recency_score, :float, null: false
      add :matched_skills, {:array, :text}, null: false, default: []
      add :missing_skills, {:array, :text}, null: false, default: []
      add :explanation, :text, null: false

      add :course_id, references(:courses, type: :uuid, on_delete: :nilify_all)
      add :class_id, references(:classes, type: :uuid, on_delete: :nilify_all)

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:rag_job_matches, [:analysis_id, :job_id],
             name: :rag_job_matches_analysis_job_index
           )

    create index(:rag_job_matches, [:analysis_id, :rank_position])
  end

  def down do
    drop table(:rag_job_matches)
    drop table(:rag_cv_analyses)

    execute("drop index if exists rag_embeddings_embedding_hnsw_index")

    drop constraint(:rag_embeddings, :rag_embeddings_owner_type_check)
    drop constraint(:rag_embeddings, :rag_embeddings_dimensions_check)

    drop table(:rag_embeddings)
  end
end
