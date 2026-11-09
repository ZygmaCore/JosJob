defmodule Stellar.Payments.Stripe.FormEncoderTest do
  use ExUnit.Case, async: true

  alias Stellar.Payments.Stripe.FormEncoder

  test "encodes flat params as strings" do
    assert FormEncoder.encode(%{"amount" => 1000, "currency" => "usd"}) |> Enum.sort() ==
             [{"amount", "1000"}, {"currency", "usd"}]
  end

  test "encodes nested maps with bracket notation" do
    assert FormEncoder.encode(%{"metadata" => %{"user_id" => "u_1"}}) ==
             [{"metadata[user_id]", "u_1"}]
  end

  test "encodes lists with numeric indices" do
    encoded = FormEncoder.encode(%{"items" => [%{"price" => "price_1", "quantity" => 2}]})

    assert Enum.sort(encoded) == [
             {"items[0][price]", "price_1"},
             {"items[0][quantity]", "2"}
           ]
  end

  test "drops nil values" do
    assert FormEncoder.encode(%{"description" => nil, "amount" => 500}) ==
             [{"amount", "500"}]
  end

  test "encodes booleans as strings" do
    assert FormEncoder.encode(%{"enabled" => true}) == [{"enabled", "true"}]
  end

  test "produces query strings Stripe accepts via URI.encode_query/1" do
    query =
      %{"metadata" => %{"user_id" => "u_1"}}
      |> FormEncoder.encode()
      |> URI.encode_query()

    assert query == "metadata%5Buser_id%5D=u_1"
  end
end
