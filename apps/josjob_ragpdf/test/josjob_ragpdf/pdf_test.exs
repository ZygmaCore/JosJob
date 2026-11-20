defmodule JosjobRagpdf.PdfTest do
  use ExUnit.Case, async: true

  alias JosjobRagpdf.Pdf

  @pdf_tools_available System.find_executable("qpdf") != nil and
                         System.find_executable("pdftotext") != nil

  describe "chunk_ranges/3" do
    test "returns no chunks for non-positive totals" do
      assert Pdf.chunk_ranges(0) == []
      assert Pdf.chunk_ranges(-1) == []
      assert Pdf.chunk_ranges(-100, 6, 1) == []
    end

    test "returns one chunk when the document fits" do
      assert Pdf.chunk_ranges(1) == [{1, 1}]
      assert Pdf.chunk_ranges(3, 6, 1) == [{1, 3}]
      assert Pdf.chunk_ranges(6) == [{1, 6}]
      assert Pdf.chunk_ranges(4, 4, 3) == [{1, 4}]
    end

    test "matches the contract example" do
      assert Pdf.chunk_ranges(7, 6, 1) == [{1, 6}, {6, 7}]
    end

    test "uses a default maximum of six pages and one page of overlap" do
      assert Pdf.chunk_ranges(7) == [{1, 6}, {6, 7}]
      assert Pdf.chunk_ranges(12) == [{1, 6}, {6, 11}, {11, 12}]
    end

    test "does not overlap when overlap is zero" do
      assert Pdf.chunk_ranges(7, 6, 0) == [{1, 6}, {7, 7}]
      assert Pdf.chunk_ranges(13, 6, 0) == [{1, 6}, {7, 12}, {13, 13}]
    end

    test "clamps overlap into 0..max_pages-1" do
      assert Pdf.chunk_ranges(7, 6, -3) == [{1, 6}, {7, 7}]
      assert Pdf.chunk_ranges(7, 6, 5) == [{1, 6}, {2, 7}]
      assert Pdf.chunk_ranges(7, 6, 99) == [{1, 6}, {2, 7}]
    end

    test "treats non-positive max_pages as one page" do
      assert Pdf.chunk_ranges(3, 0, 0) == [{1, 1}, {2, 2}, {3, 3}]
      assert Pdf.chunk_ranges(3, -5, 2) == [{1, 1}, {2, 2}, {3, 3}]
    end

    test "every chunk advances, stays within max_pages and the last one ends at total" do
      for total <- 7..40, max_pages <- 1..8, overlap <- 0..8 do
        ranges = Pdf.chunk_ranges(total, max_pages, overlap)

        assert ranges != []
        assert {1, _} = List.first(ranges)
        assert {_, ^total} = List.last(ranges)

        Enum.each(ranges, fn {first, last} ->
          assert first <= last
          assert first >= 1
          assert last <= total
          assert last - first + 1 <= max_pages
        end)

        ranges
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [{first, last}, {next_first, _next_last}] ->
          assert next_first > first
          assert next_first <= last + 1
        end)
      end
    end
  end

  describe "validate/1" do
    setup do
      dir = tmp_dir()
      on_exit(fn -> File.rm_rf(dir) end)
      {:ok, dir: dir}
    end

    test "returns :not_found for a missing file", %{dir: dir} do
      assert {:error, :not_found} = Pdf.validate(Path.join(dir, "missing.pdf"))
    end

    test "returns :empty for a zero-byte file", %{dir: dir} do
      path = Path.join(dir, "empty.pdf")
      File.write!(path, "")
      assert {:error, :empty} = Pdf.validate(path)
    end

    test "returns :not_pdf for arbitrary content", %{dir: dir} do
      path = Path.join(dir, "text.pdf")
      File.write!(path, "this is definitely not a pdf")
      assert {:error, :not_pdf} = Pdf.validate(path)
    end

    test "returns :not_pdf for whitespace-only content", %{dir: dir} do
      path = Path.join(dir, "spaces.pdf")
      File.write!(path, "  \r\n\t  ")
      assert {:error, :not_pdf} = Pdf.validate(path)
    end

    test "accepts a file that starts with %PDF-", %{dir: dir} do
      path = Path.join(dir, "valid.pdf")
      File.write!(path, "%PDF-1.7\n1 0 obj\n<<>>\nendobj\n%%EOF\n")
      assert :ok = Pdf.validate(path)
    end

    test "tolerates leading whitespace and a UTF-8 BOM", %{dir: dir} do
      path = Path.join(dir, "bom.pdf")
      File.write!(path, <<0xEF, 0xBB, 0xBF>> <> " \r\n\t%PDF-1.4\n%%EOF\n")
      assert :ok = Pdf.validate(path)
    end

    test "rejects a PDF header beyond the first 1024 bytes", %{dir: dir} do
      path = Path.join(dir, "late.pdf")
      File.write!(path, String.duplicate(" ", 1024) <> "%PDF-1.7\n%%EOF\n")
      assert {:error, :not_pdf} = Pdf.validate(path)
    end

    test "rejects invalid page ranges before invoking qpdf" do
      assert {:error, {:invalid_range, {0, 2}}} = Pdf.split("/nope.pdf", {0, 2}, "/tmp/out.pdf")
      assert {:error, {:invalid_range, {3, 2}}} = Pdf.split("/nope.pdf", {3, 2}, "/tmp/out.pdf")
    end
  end

  if @pdf_tools_available do
    describe "with qpdf and pdftotext installed" do
      setup do
        dir = tmp_dir()
        on_exit(fn -> File.rm_rf(dir) end)

        path = Path.join(dir, "fixture.pdf")
        File.write!(path, build_pdf(["Page one", "Page two", "Page three"]))

        {:ok, dir: dir, path: path}
      end

      test "counts pages", %{path: path} do
        assert {:ok, 3} = Pdf.page_count(path)
      end

      test "extracts text", %{path: path} do
        assert {:ok, text} = Pdf.text(path)
        assert text =~ "Page one"
        assert text =~ "Page two"
        assert text =~ "Page three"
      end

      test "splits a page range and creates the output directory", %{dir: dir, path: path} do
        output = Path.join([dir, "nested", "pages-2-3.pdf"])

        assert :ok = Pdf.split(path, {2, 3}, output)
        assert File.exists?(output)
        assert {:ok, 2} = Pdf.page_count(output)

        assert {:ok, text} = Pdf.text(output)
        assert text =~ "Page two"
        assert text =~ "Page three"
        refute text =~ "Page one"
      end
    end

    # Builds a small, standards-compliant PDF by hand so the integration tests do
    # not depend on fixture files or extra dependencies.
    defp build_pdf(pages) do
      count = length(pages)
      font_number = 3 + 2 * count
      page_numbers = Enum.map(0..(count - 1), fn index -> 3 + 2 * index end)
      kids = Enum.map_join(page_numbers, " ", &"#{&1} 0 R")

      page_objects =
        pages
        |> Enum.with_index()
        |> Enum.flat_map(fn {text, index} ->
          page_number = 3 + 2 * index
          contents_number = page_number + 1
          content = "BT /F1 18 Tf 50 150 Td (#{escape_pdf(text)}) Tj ET"

          [
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] " <>
              "/Contents #{contents_number} 0 R " <>
              "/Resources << /Font << /F1 #{font_number} 0 R >> >> >>",
            "<< /Length #{byte_size(content)} >>\nstream\n#{content}\nendstream"
          ]
        end)

      objects =
        [
          "<< /Type /Catalog /Pages 2 0 R >>",
          "<< /Type /Pages /Kids [#{kids}] /Count #{count} >>"
        ] ++
          page_objects ++
          ["<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]

      header = "%PDF-1.4\n"

      {body, offsets, xref_offset} =
        objects
        |> Enum.with_index(1)
        |> Enum.reduce({[], [], byte_size(header)}, fn {object, number},
                                                       {body, offsets, position} ->
          chunk = "#{number} 0 obj\n#{object}\nendobj\n"
          {[chunk | body], [{number, position} | offsets], position + byte_size(chunk)}
        end)

      body = body |> Enum.reverse() |> IO.iodata_to_binary()
      offsets = Enum.reverse(offsets)

      size = length(objects) + 1

      xref_entries =
        Enum.map(offsets, fn {_number, offset} ->
          [String.pad_leading(Integer.to_string(offset), 10, "0"), " 00000 n \n"]
        end)

      xref = ["xref\n0 #{size}\n0000000000 65535 f \n", xref_entries]
      trailer = "trailer\n<< /Size #{size} /Root 1 0 R >>\nstartxref\n#{xref_offset}\n%%EOF\n"

      IO.iodata_to_binary([header, body, xref, trailer])
    end

    defp escape_pdf(text) do
      text
      |> String.replace("\\", "\\\\")
      |> String.replace("(", "\\(")
      |> String.replace(")", "\\)")
    end
  end

  defp tmp_dir do
    dir =
      Path.join(
        System.tmp_dir!(),
        "josjob_ragpdf-pdf-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end
end
