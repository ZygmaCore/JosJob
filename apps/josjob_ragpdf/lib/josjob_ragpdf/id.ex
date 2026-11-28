defmodule JosjobRagpdf.Id do
  @moduledoc "Opaque URL-safe ids for jobs."

  @doc "Generate an opaque id such as `job_...`."
  def generate(prefix \\ "job") when is_binary(prefix) do
    "#{prefix}_#{Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)}"
  end
end
