defmodule Josjob.Payments.Stripe.FormEncoder do
  @moduledoc """
  Encode map/list bersarang menjadi parameter form ala Stripe:

      %{"metadata" => %{"user_id" => "u_1"}}        -> [{"metadata[user_id]", "u_1"}]
      %{"items" => [%{"price" => "price_1"}]}        -> [{"items[0][price]", "price_1"}]

  Hasilnya daftar tuple `{key, value}` string yang siap diteruskan ke
  `URI.encode_query/1`. Nilai `nil` dibuang (Stripe memperlakukan key absen =
  tidak di-set). Masukan diasumsikan map (bukan keyword list).
  """
  @spec encode(map()) :: [{String.t(), String.t()}]
  def encode(params) when is_map(params) do
    Enum.flat_map(params, fn {key, value} -> encode_pair(to_string(key), value) end)
  end

  defp encode_pair(_key, nil), do: []

  defp encode_pair(key, %{} = value) do
    Enum.flat_map(value, fn {k, v} -> encode_pair("#{key}[#{k}]", v) end)
  end

  defp encode_pair(key, value) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.flat_map(fn {v, index} -> encode_pair("#{key}[#{index}]", v) end)
  end

  defp encode_pair(key, value) when is_boolean(value) do
    [{key, to_string(value)}]
  end

  defp encode_pair(key, value) do
    [{key, to_string(value)}]
  end
end
