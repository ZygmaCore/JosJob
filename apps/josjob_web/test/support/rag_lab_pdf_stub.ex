defmodule JosjobWeb.RagLabPdfStub do
  @moduledoc false
  # Stub test-only untuk `JosjobRag.PdfClient` di `RagLabLiveTest`.
  # Jangan dipakai di runtime.

  @done %{
    "status" => "done",
    "pages" => 3,
    "chunks_done" => 1,
    "chunks_total" => 1,
    "result" => %{
      "skills" => ["Elixir", "PostgreSQL"],
      "experience" => [%{"title" => "Backend Engineer"}],
      "education" => []
    }
  }

  def submit_upload(_upload, _user_id, cv_id, _opts \\ []) do
    {:ok,
     %{
       "data" => %{
         "id" => "job_stub",
         "cv_id" => cv_id,
         "status" => "queued",
         "queue_position" => 0
       }
     }}
  end

  def get("job_stub", _opts \\ []), do: {:ok, %{"data" => @done}}
end
