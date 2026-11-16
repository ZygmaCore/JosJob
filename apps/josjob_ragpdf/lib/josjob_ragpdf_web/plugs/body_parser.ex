defmodule JosjobRagpdfWeb.Plugs.BodyParser do
  @moduledoc """
  Wraps `Plug.Parsers` so the body-size limit follows runtime config instead of
  being frozen at compile time (the `plug` macro calls `init/1` at compile).
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    max_pdf_bytes = Application.get_env(:josjob_ragpdf, :max_pdf_bytes, 10_000_000)

    # Multipart/JSON envelopes add overhead on top of the raw PDF bytes.
    limit = max(max_pdf_bytes * 2 + 1_000_000, 2_000_000)

    opts =
      Plug.Parsers.init(
        parsers: [:multipart, :json, :urlencoded],
        pass: ["application/json"],
        json_decoder: Jason,
        length: limit
      )

    Plug.Parsers.call(conn, opts)
  end
end
