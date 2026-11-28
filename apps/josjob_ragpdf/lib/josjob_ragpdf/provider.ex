defmodule JosjobRagpdf.Provider do
  @moduledoc """
  Behaviour implemented by every CV extraction provider.

  A provider receives either a local PDF path (`extract_pdf/2`) or already
  extracted plain text (`extract_text/2`) and returns a normalized-by-caller
  map of CV fields plus a meta map describing who produced the answer.

  Providers must never raise for expected failures (bad status, timeout,
  unparseable body). They return `{:error, reason}` instead so `JosjobRagpdf.AI` can
  fall back to the next provider.

  The `meta` map uses atom keys:

    * `:provider` — provider name as a string (`"gemini"`, ...)
    * `:model` — model identifier or `nil`
    * `:usage` — token usage map or `nil`
  """

  @type result :: map()

  @type meta :: %{
          optional(:provider) => String.t(),
          optional(:model) => String.t() | nil,
          optional(:usage) => map() | nil
        }

  @doc "Extract CV data from a local PDF file."
  @callback extract_pdf(path :: String.t(), opts :: keyword()) ::
              {:ok, result(), meta()} | {:error, term()}

  @doc "Extract CV data from plain text (already extracted from a PDF)."
  @callback extract_text(text :: String.t(), opts :: keyword()) ::
              {:ok, result(), meta()} | {:error, term()}
end
