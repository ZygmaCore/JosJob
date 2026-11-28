defmodule JosjobRagpdf.Temp do
  @moduledoc "Per-job temporary directory helpers. Every job cleans up after itself."

  @doc "Root temp directory for this service."
  def root do
    Application.get_env(:josjob_ragpdf, :tmp_dir) || Path.join(System.tmp_dir!(), "josjob_ragpdf")
  end

  @doc "Directory for one job."
  def job_dir(job_id) when is_binary(job_id), do: Path.join(root(), job_id)

  @doc "Create the per-job directory and return it."
  def ensure_job_dir(job_id) when is_binary(job_id) do
    dir = job_dir(job_id)
    File.mkdir_p!(dir)
    dir
  end

  @doc "Remove the per-job directory. Missing directories are ignored."
  def cleanup(job_id) when is_binary(job_id) do
    File.rm_rf(job_dir(job_id))
    :ok
  end
end
