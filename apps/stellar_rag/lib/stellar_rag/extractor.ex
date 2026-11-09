defmodule StellarRag.Extractor do
  @moduledoc """
  Extracts raw text content from uploaded document files using Xberg.
  """

  require Logger

  @doc """
  Extracts text content from a file path using Xberg.
  Returns {:ok, text} or {:error, reason}.
  """
  def extract(file_path) do
    Logger.info("Extracting text from document: #{file_path}")

    case Xberg.extract(input: %Xberg.ExtractInput{kind: :uri, uri: file_path}) do
      {:ok, {:ok, result}} ->
        parse_extraction_result(result)

      {:ok, result} ->
        parse_extraction_result(result)

      {:error, reason} ->
        Logger.error("Failed to extract text using Xberg: #{inspect(reason)}")
        {:error, reason}

      {:error, type, message} ->
        Logger.error("Failed to extract text using Xberg: #{type} - #{message}")
        {:error, {type, message}}

      other ->
        Logger.warning("Xberg returned unexpected format: #{inspect(other)}")
        {:error, {:unexpected_xberg_format, other}}
    end
  rescue
    e ->
      Logger.error("Exception during Xberg extraction: #{inspect(e)}")
      {:error, e}
  end

  defp parse_extraction_result(%Xberg.ExtractionResult{results: results}) when is_list(results) do
    parse_results_list(results)
  end

  defp parse_extraction_result(%{results: results}) when is_list(results) do
    parse_results_list(results)
  end

  defp parse_extraction_result(other) do
    Logger.warning("Unrecognized extraction result structure: #{inspect(other)}")
    {:error, :no_content_found}
  end

  defp parse_results_list([first | _]) do
    content =
      Map.get(first, :content) ||
        Map.get(first, :text) ||
        Map.get(first, :djot_content)

    case content do
      c when is_binary(c) and c != "" -> {:ok, c}
      _ -> {:error, :no_content_found}
    end
  end

  defp parse_results_list([]) do
    {:error, :no_content_found}
  end
end
