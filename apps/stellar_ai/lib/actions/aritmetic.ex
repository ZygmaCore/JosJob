defmodule StellarAi.Actions.Arithmetic do
  @moduledoc """
  Provides basic arithmetic operations as actions.
  """

  alias Jido.Action

  defmodule Add do
    @moduledoc false
    use Action,
      name: "add",
      description: "Adds two numbers",
      schema:
        Zoi.object(
          %{
            value: Zoi.number(description: "The first number to add"),
            amount: Zoi.number(description: "The second number to add")
          },
          coerce: true
        )

    @spec run(map(), map()) :: {:ok, map()}
    def run(%{value: value, amount: amount}, _context) do
      IO.puts(">>> ADDING #{value} + #{amount}")
      {:ok, %{result: value + amount}}
    end
  end

  defmodule Subtract do
    @moduledoc false
    use Action,
      name: "subtract",
      description: "Subtracts one number from another",
      schema:
        Zoi.object(
          %{
            value: Zoi.number(description: "The number to subtract from"),
            amount: Zoi.number(description: "The number to subtract")
          },
          coerce: true
        )

    @spec run(map(), map()) :: {:ok, map()}
    def run(%{value: value, amount: amount}, _context) do
      {:ok, %{result: value - amount}}
    end
  end

  defmodule Multiply do
    @moduledoc false
    use Action,
      name: "multiply",
      description: "Multiplies two numbers",
      schema:
        Zoi.object(
          %{
            value: Zoi.number(description: "The first number to multiply"),
            amount: Zoi.number(description: "The second number to multiply")
          },
          coerce: true
        )

    @spec run(map(), map()) :: {:ok, map()}
    def run(%{value: value, amount: amount}, _context) do
      {:ok, %{result: value * amount}}
    end
  end

  defmodule Divide do
    @moduledoc false
    use Action,
      name: "divide",
      description: "Divides one number by another",
      schema:
        Zoi.object(
          %{
            value: Zoi.number(description: "The number to be divided (dividend)"),
            amount: Zoi.number(description: "The number to divide by (divisor)")
          },
          coerce: true
        )

    @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
    def run(%{value: _value, amount: amount}, _context) when amount == 0 or amount == 0.0 do
      {:error, "Cannot divide by zero"}
    end

    def run(%{value: value, amount: amount}, _context) do
      {:ok, %{result: value / amount}}
    end
  end

  defmodule Square do
    @moduledoc false
    use Action,
      name: "square",
      description: "Squares a number",
      schema:
        Zoi.object(
          %{
            value: Zoi.number(description: "The number to be squared")
          },
          coerce: true
        )

    @spec run(map(), map()) :: {:ok, map()}
    def run(%{value: value}, _context) do
      {:ok, %{result: value * value}}
    end
  end
end
