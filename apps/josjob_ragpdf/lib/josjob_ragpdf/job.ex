defmodule JosjobRagpdf.Job do
  @moduledoc """
  One CV analysis job.

  `:source` is internal and must never be serialized to HTTP clients:

    * `{:upload, path}` — the controller already stored the PDF on disk
    * `{:url, url}` — the worker downloads it
    * `{:base64, data}` — the worker decodes it

  `:status` is one of `:queued`, `:processing`, `:done`, `:partial`,
  `:unreadable`, `:failed`.
  """

  @enforce_keys [:id, :user_id, :status, :inserted_at]
  defstruct [
    :id,
    :user_id,
    :cv_id,
    :filename,
    :source,
    :path,
    :status,
    :pages,
    :chunks_total,
    :chunks_done,
    :result,
    :error,
    :warnings,
    :known_skills,
    :provider,
    :model,
    :inserted_at,
    :started_at,
    :finished_at,
    :idempotency_key
  ]

  @type status :: :queued | :processing | :done | :partial | :unreadable | :failed
  @type t :: %__MODULE__{}

  @terminal [:done, :partial, :unreadable, :failed]

  @spec terminal?(t()) :: boolean()
  def terminal?(%__MODULE__{status: status}), do: status in @terminal

  @spec status_string(t()) :: String.t()
  def status_string(%__MODULE__{status: status}), do: Atom.to_string(status)
end
