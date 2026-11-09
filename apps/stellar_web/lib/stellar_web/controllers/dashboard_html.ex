defmodule StellarWeb.DashboardHTML do
  use StellarWeb, :html

  embed_templates "dashboard_html/*"

  @doc "Rakit string CSS conic-gradient dari daftar slice pie."
  def pie_gradient(slices) do
    total = slices |> Enum.map(& &1.value) |> Enum.sum()

    {segments, _} =
      Enum.reduce(slices, {[], 0.0}, fn s, {acc, start} ->
        stop = start + s.value / total * 100
        {["#{s.color} #{fmt(start)}% #{fmt(stop)}%" | acc], stop}
      end)

    "conic-gradient(" <> Enum.join(Enum.reverse(segments), ", ") <> ")"
  end

  @doc "Persentase (1 desimal) untuk legend."
  def pct(value, total), do: fmt(value / total * 100)

  @doc "Tinggi bar (%) relatif nilai maksimum."
  def bar_height(value, max), do: fmt(value / max * 100)

  defp fmt(n), do: :erlang.float_to_binary(n * 1.0, decimals: 1)
end
