defmodule JosjobRagpdf do
  @moduledoc """
  Standalone PDF CV extraction microservice.

  This app is intentionally **not** part of the root JosJob umbrella release.
  It owns the Gemini/9Router extraction pipeline (F6), PDF chunking, and the
  in-memory queue. See `CONTRACT.md` for the module and HTTP contracts.
  """
end
