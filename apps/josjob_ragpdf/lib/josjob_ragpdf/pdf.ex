defmodule JosjobRagpdf.Pdf do
  @moduledoc """
  Thin wrapper around the external `qpdf` and `pdftotext` binaries.

  The worker relies on this module only through this interface, so tests can
  inject a fake module (`opts[:pdf]` on `JosjobRagpdf.Worker`). The binary names are
  configurable:

      config :josjob_ragpdf, qpdf_bin: "qpdf", pdftotext_bin: "pdftotext"

  Every function takes an explicit path; nothing here keeps state.
  """

  @type page_range :: {pos_integer(), pos_integer()}

  @type error ::
          {:command_failed, non_neg_integer(), binary()}
          | {:command_not_found, binary()}
          | {:command_not_executable, binary()}
          | {:command_error, term()}
          | {:invalid_output, binary()}
          | {:invalid_range, term()}
          | {:mkdir_failed, Path.t(), term()}
          | :not_found
          | :not_pdf
          | :empty

  @default_max_pages 6
  @default_overlap 1

  @header "%PDF-"
  @header_window 1024
  @utf8_bom <<0xEF, 0xBB, 0xBF>>
  @blank_bytes [?\s, ?\t, ?\r, ?\n, ?\v, ?\f, 0]

  @doc """
  Returns the number of pages reported by `qpdf --show-npages`.
  """
  @spec page_count(Path.t()) :: {:ok, non_neg_integer()} | {:error, error()}
  def page_count(path) when is_binary(path) do
    with {:ok, output} <- run(qpdf_bin(), ["--show-npages", path]) do
      parse_count(output)
    end
  end

  @doc """
  Extracts the inclusive page range `{first, last}` into `output_path`.

  Missing parent directories of `output_path` are created. Any existing file at
  `output_path` is overwritten by qpdf.
  """
  @spec split(Path.t(), page_range(), Path.t()) :: :ok | {:error, error()}
  def split(path, {first, last}, output_path)
      when is_binary(path) and is_integer(first) and is_integer(last) and
             first >= 1 and last >= first and is_binary(output_path) do
    with :ok <- ensure_parent_dir(output_path) do
      args = [path, "--pages", ".", "#{first}-#{last}", "--", output_path]

      case run(qpdf_bin(), args) do
        {:ok, _output} -> :ok
        {:error, _reason} = error -> error
      end
    end
  end

  def split(_path, range, _output_path), do: {:error, {:invalid_range, range}}

  @doc """
  Extracts the text layer with `pdftotext -layout PATH -`.

  `-` makes pdftotext write to stdout, so the text is returned instead of
  written next to the input.
  """
  @spec text(Path.t()) :: {:ok, binary()} | {:error, error()}
  def text(path) when is_binary(path) do
    # Keep stderr out of the extracted text; on failure the third tuple element
    # holds whatever stdout produced.
    run(pdftotext_bin(), ["-layout", path, "-"], stderr_to_stdout: false)
  end

  @doc """
  Cheap structural validation without invoking external tools.

    * `{:error, :not_found}` when the path does not exist
    * `{:error, :empty}` for a zero-byte file
    * `{:error, :not_pdf}` unless `%PDF-` appears within the first 1024 bytes,
      after optional leading blank bytes/BOM
    * `:ok` otherwise
  """
  @spec validate(Path.t()) :: :ok | {:error, :not_found | :not_pdf | :empty}
  def validate(path) when is_binary(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular, size: 0}} -> {:error, :empty}
      {:ok, %File.Stat{type: :regular}} -> validate_header(path)
      {:ok, _stat} -> {:error, :not_pdf}
      {:error, _reason} -> {:error, :not_found}
    end
  end

  def validate(_path), do: {:error, :not_found}

  @doc """
  Splits `total` pages into overlapping inclusive ranges.

  Guarantees:

    * `total <= 0` returns `[]`
    * a document that fits in one chunk returns `[{1, total}]`
    * no chunk spans more than `max_pages` pages
    * `overlap` is clamped to `0..(max_pages - 1)`
    * consecutive chunks always advance and the final chunk ends at `total`

  ## Examples

      iex> JosjobRagpdf.Pdf.chunk_ranges(7, 6, 1)
      [{1, 6}, {6, 7}]

      iex> JosjobRagpdf.Pdf.chunk_ranges(13, 6, 0)
      [{1, 6}, {7, 12}, {13, 13}]

      iex> JosjobRagpdf.Pdf.chunk_ranges(3, 6, 1)
      [{1, 3}]

  """
  @spec chunk_ranges(integer(), integer(), integer()) :: [page_range()]
  def chunk_ranges(total, max_pages \\ @default_max_pages, overlap \\ @default_overlap)

  def chunk_ranges(total, _max_pages, _overlap) when not is_integer(total), do: []

  def chunk_ranges(total, _max_pages, _overlap) when total <= 0, do: []

  def chunk_ranges(total, max_pages, overlap) do
    max_pages = normalize_max_pages(max_pages)
    overlap = normalize_overlap(overlap, max_pages)

    if total <= max_pages do
      [{1, total}]
    else
      build_ranges(1, total, max_pages, overlap, [])
    end
  end

  # -- chunking helpers -------------------------------------------------------

  defp normalize_max_pages(max_pages) when is_integer(max_pages) and max_pages > 0,
    do: max_pages

  defp normalize_max_pages(_max_pages), do: 1

  defp normalize_overlap(overlap, max_pages) when is_integer(overlap) do
    overlap
    |> min(max_pages - 1)
    |> max(0)
  end

  defp normalize_overlap(_overlap, _max_pages), do: 0

  defp build_ranges(first, total, max_pages, overlap, acc) do
    last = min(first + max_pages - 1, total)
    acc = [{first, last} | acc]

    if last >= total do
      Enum.reverse(acc)
    else
      # Overlap counts shared pages: with overlap 1 the next chunk starts on the
      # previous chunk's last page (e.g. {1, 6} -> {6, 7}).
      next_first = max(last - overlap + 1, first + 1)
      build_ranges(next_first, total, max_pages, overlap, acc)
    end
  end

  # -- output -----------------------------------------------------------------

  defp parse_count(output) do
    trimmed = String.trim(output)

    case parse_integer(trimmed) do
      {:ok, count} ->
        {:ok, count}

      :error ->
        # qpdf warnings share the stdout stream when stderr is redirected; fall
        # back to the last line that is a bare non-negative integer.
        case find_integer_line(output) do
          nil -> {:error, {:invalid_output, trimmed}}
          count -> {:ok, count}
        end
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {count, ""} when count >= 0 -> {:ok, count}
      _other -> :error
    end
  end

  defp find_integer_line(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      case parse_integer(String.trim(line)) do
        {:ok, count} -> count
        :error -> nil
      end
    end)
  end

  # -- validation helpers -----------------------------------------------------

  defp validate_header(path) do
    case read_prefix(path) do
      {:ok, prefix} -> if pdf_header?(prefix), do: :ok, else: {:error, :not_pdf}
      {:error, _reason} -> {:error, :not_pdf}
    end
  end

  defp read_prefix(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, io} ->
        try do
          case IO.binread(io, @header_window) do
            data when is_binary(data) -> {:ok, data}
            :eof -> {:ok, ""}
            {:error, reason} -> {:error, reason}
          end
        after
          File.close(io)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp pdf_header?(prefix) do
    prefix
    |> strip_boms()
    |> strip_leading_blank()
    |> String.starts_with?(@header)
  end

  defp strip_boms(@utf8_bom <> rest), do: strip_boms(rest)
  defp strip_boms(binary), do: binary

  defp strip_leading_blank(<<byte, rest::binary>>) when byte in @blank_bytes,
    do: strip_leading_blank(rest)

  defp strip_leading_blank(binary), do: binary

  # -- filesystem helpers -----------------------------------------------------

  defp ensure_parent_dir(output_path) do
    dir = Path.dirname(output_path)

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, dir, reason}}
    end
  end

  # -- command helpers --------------------------------------------------------

  defp run(bin, args, opts \\ []) do
    cmd_opts = Keyword.merge([stderr_to_stdout: true], opts)

    case System.cmd(bin, args, cmd_opts) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, {:command_failed, status, output}}
    end
  rescue
    error in ErlangError ->
      case error.original do
        :enoent -> {:error, {:command_not_found, bin}}
        :eacces -> {:error, {:command_not_executable, bin}}
        reason -> {:error, {:command_error, reason}}
      end
  end

  defp qpdf_bin, do: Application.get_env(:josjob_ragpdf, :qpdf_bin) || "qpdf"
  defp pdftotext_bin, do: Application.get_env(:josjob_ragpdf, :pdftotext_bin) || "pdftotext"
end
