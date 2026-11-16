defmodule JosjobRag.ExtractorTest do
  use ExUnit.Case, async: true

  alias JosjobRag.Extractor

  setup do
    # Create a temporary file to test extraction
    tmp_path = Path.join(System.tmp_dir!(), "test_extraction_#{path_random_suffix()}.txt")
    File.write!(tmp_path, "Hello from Josjob RAG extraction tests!")

    on_exit(fn ->
      File.rm(tmp_path)
    end)

    {:ok, tmp_path: tmp_path}
  end

  test "extract/1 successfully retrieves plain text from a text file", %{tmp_path: tmp_path} do
    assert {:ok, content} = Extractor.extract(tmp_path)
    assert content =~ "Hello from Josjob RAG extraction"
  end

  test "extract/1 returns error for non-existent file" do
    assert {:error, _reason} = Extractor.extract("non_existent_file.pdf")
  end

  defp path_random_suffix do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
