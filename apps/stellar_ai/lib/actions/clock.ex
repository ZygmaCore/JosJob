defmodule StellarAi.Actions.Clock do
  use Jido.Action,
    name: "clock",
    description:
      "Performs semantic time lookups (e.g., 'now', '3 hours from now', '30 minutes ago') and returns a detailed time object.",
    schema: [
      expression: [
        type: :string,
        required: false,
        doc:
          "Semantic time expression to look up (e.g., 'now', '3 hours from now', '30 minutes ago')."
      ],
      base_time: [
        type: :string,
        required: false,
        doc: "The base reference time in HH:MM:SS format or ISO8601. Defaults to current time."
      ],
      timezone_offset: [
        type: :integer,
        required: false,
        doc: "Timezone offset in hours. Defaults to 7 (for +07:00)."
      ],
      calculation: [
        type: :map,
        required: false,
        doc:
          "Map with keys 'op' ('add' | 'subtract'), 'amount' (integer), and 'unit' ('hours' | 'minutes' | 'seconds')."
      ]
    ]

  require Logger

  def run(params, _context) do
    offset_hours = Map.get(params, :timezone_offset) || 7

    base_dt =
      case Map.get(params, :base_time) do
        nil -> get_current_local_time(offset_hours)
        str -> parse_base_time(str, offset_hours)
      end

    cond do
      Map.get(params, :calculation) != nil ->
        calc = params.calculation
        op = Map.get(calc, :op) || Map.get(calc, "op")
        amount = Map.get(calc, :amount) || Map.get(calc, "amount")
        unit = Map.get(calc, :unit) || Map.get(calc, "unit")

        cond do
          is_nil(op) or is_nil(amount) or is_nil(unit) ->
            {:error, "Calculation map must contain 'op', 'amount', and 'unit'"}

          op not in ["add", "subtract", :add, :subtract] ->
            {:error, "Calculation 'op' must be either 'add' or 'subtract'"}

          not is_integer(amount) ->
            {:error, "Calculation 'amount' must be an integer"}

          true ->
            {:ok, format_time_object(calculate_time(base_dt, op, amount, unit))}
        end

      Map.get(params, :expression) != nil ->
        case parse_semantic_expression(params.expression, base_dt) do
          {:ok, result_dt} -> {:ok, format_time_object(result_dt)}
          {:error, reason} -> {:error, reason}
        end

      true ->
        # Default to "now" if nothing is provided
        {:ok, format_time_object(base_dt)}
    end
  end

  def parse_semantic_expression(expression, base_dt) do
    expr = String.downcase(expression) |> String.trim()

    cond do
      expr in ["now", "sekarang", "current time", "waktu sekarang", "current"] ->
        {:ok, base_dt}

      # relative hours future
      Regex.match?(~r/^(\d+)\s+(hours?|jam)\s+(from now|lagi)$/i, expr) ->
        [_, amount_str, _, _] = Regex.run(~r/^(\d+)\s+(hours?|jam)\s+(from now|lagi)$/i, expr)
        amount = String.to_integer(amount_str)
        {:ok, DateTime.add(base_dt, amount * 3600, :second)}

      # relative hours past
      Regex.match?(~r/^(\d+)\s+(hours?|jam)\s+(ago|yang lalu|lalu)$/i, expr) ->
        [_, amount_str, _, _] =
          Regex.run(~r/^(\d+)\s+(hours?|jam)\s+(ago|yang lalu|lalu)$/i, expr)

        amount = String.to_integer(amount_str)
        {:ok, DateTime.add(base_dt, -amount * 3600, :second)}

      # relative minutes future
      Regex.match?(~r/^(\d+)\s+(minutes?|menit)\s+(from now|lagi)$/i, expr) ->
        [_, amount_str, _, _] = Regex.run(~r/^(\d+)\s+(minutes?|menit)\s+(from now|lagi)$/i, expr)
        amount = String.to_integer(amount_str)
        {:ok, DateTime.add(base_dt, amount * 60, :second)}

      # relative minutes past
      Regex.match?(~r/^(\d+)\s+(minutes?|menit)\s+(ago|yang lalu|lalu)$/i, expr) ->
        [_, amount_str, _, _] =
          Regex.run(~r/^(\d+)\s+(minutes?|menit)\s+(ago|yang lalu|lalu)$/i, expr)

        amount = String.to_integer(amount_str)
        {:ok, DateTime.add(base_dt, -amount * 60, :second)}

      # relative seconds future
      Regex.match?(~r/^(\d+)\s+(seconds?|detik)\s+(from now|lagi)$/i, expr) ->
        [_, amount_str, _, _] = Regex.run(~r/^(\d+)\s+(seconds?|detik)\s+(from now|lagi)$/i, expr)
        amount = String.to_integer(amount_str)
        {:ok, DateTime.add(base_dt, amount, :second)}

      # relative seconds past
      Regex.match?(~r/^(\d+)\s+(seconds?|detik)\s+(ago|yang lalu|lalu)$/i, expr) ->
        [_, amount_str, _, _] =
          Regex.run(~r/^(\d+)\s+(seconds?|detik)\s+(ago|yang lalu|lalu)$/i, expr)

        amount = String.to_integer(amount_str)
        {:ok, DateTime.add(base_dt, -amount, :second)}

      true ->
        {:error, "Unsupported semantic expression: #{expression}"}
    end
  end

  def calculate_time(base_dt, op, amount, unit) do
    multiplier = if op in ["subtract", :subtract], do: -1, else: 1
    total_amount = amount * multiplier

    case normalize_unit(unit) do
      "hours" ->
        DateTime.add(base_dt, total_amount * 3600, :second)

      "minutes" ->
        DateTime.add(base_dt, total_amount * 60, :second)

      "seconds" ->
        DateTime.add(base_dt, total_amount, :second)
    end
  end

  defp get_current_local_time(offset_hours) do
    DateTime.utc_now()
    |> DateTime.add(offset_hours * 3600, :second)
  end

  defp parse_base_time(str, offset_hours) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} ->
        dt

      _ ->
        case Time.from_iso8601(str) do
          {:ok, time} ->
            local_dt = get_current_local_time(offset_hours)
            DateTime.new!(DateTime.to_date(local_dt), time, local_dt.time_zone)

          _ ->
            get_current_local_time(offset_hours)
        end
    end
  end

  defp normalize_unit(unit) do
    u = String.downcase(to_string(unit))

    cond do
      u in ["hour", "hours", "jam"] -> "hours"
      u in ["minute", "minutes", "menit"] -> "minutes"
      u in ["second", "seconds", "detik"] -> "seconds"
      true -> u
    end
  end

  defp format_time_object(dt) do
    # Convert DateTime to local time string HH:MM:SS
    # Wait, dt has hour, minute, second. We can use a simple padding
    h = dt.hour |> to_string() |> String.pad_leading(2, "0")
    m = dt.minute |> to_string() |> String.pad_leading(2, "0")
    s = dt.second |> to_string() |> String.pad_leading(2, "0")
    time_str = "#{h}:#{m}:#{s}"

    %{
      time: time_str,
      hour: dt.hour,
      minute: dt.minute,
      second: dt.second,
      formatted: time_str,
      iso8601: DateTime.to_iso8601(dt)
    }
  end
end
