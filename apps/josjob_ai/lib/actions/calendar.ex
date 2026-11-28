defmodule JosjobAi.Actions.Calendar do
  use Jido.Action,
    name: "calendar",
    description:
      "Performs semantic date lookups (e.g., 'tomorrow', 'next Monday', 'this weekend') and date calculations (add/subtract days, weeks, months, or years from a reference date).",
    schema:
      Zoi.object(
        %{
          expression:
            Zoi.string(
              description:
                "Semantic date expression to look up (e.g., 'tomorrow', 'next Monday', 'this weekend')."
            ),
          base_date:
            Zoi.string(
              description:
                "The base reference date in YYYY-MM-DD format. Defaults to today's date."
            ),
          calculation:
            Zoi.map(
              description:
                "Map with keys 'op' ('add' | 'subtract'), 'amount' (integer), and 'unit' ('days' | 'weeks' | 'months' | 'years')."
            )
        },
        coerce: true
      )

  require Logger

  @days %{
    "monday" => 1,
    "senin" => 1,
    "tuesday" => 2,
    "selasa" => 2,
    "wednesday" => 3,
    "rabu" => 3,
    "thursday" => 4,
    "kamis" => 4,
    "friday" => 5,
    "jumat" => 5,
    "saturday" => 6,
    "sabtu" => 6,
    "sunday" => 7,
    "minggu" => 7
  }

  def run(params, _context) do
    base_date =
      case Map.get(params, :base_date) do
        nil -> Date.utc_today()
        str -> Date.from_iso8601!(str)
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
            {:ok, calculate_date(base_date, op, amount, unit)}
        end

      Map.get(params, :expression) != nil ->
        case parse_semantic_expression(params.expression, base_date) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
        end

      true ->
        {:error, "Either 'expression' or 'calculation' must be provided."}
    end
  end

  def parse_semantic_expression(expression, base_date) do
    expr = String.downcase(expression) |> String.trim()

    cond do
      expr in ["today", "hari ini"] ->
        {:ok, %{type: "single", date: Date.to_iso8601(base_date)}}

      expr in ["tomorrow", "besok", "bes0k"] ->
        {:ok, %{type: "single", date: Date.to_iso8601(Date.add(base_date, 1))}}

      expr in ["yesterday", "kemarin", "kemaren", "kmrn", "kmrin"] ->
        {:ok, %{type: "single", date: Date.to_iso8601(Date.add(base_date, -1))}}

      expr in ["lusa"] ->
        {:ok, %{type: "single", date: Date.to_iso8601(Date.add(base_date, 2))}}

      expr in ["this weekend", "weekend ini", "akhir pekan ini"] ->
        {sat, sun} = get_weekend(base_date)
        {:ok, %{type: "range", start_date: Date.to_iso8601(sat), end_date: Date.to_iso8601(sun)}}

      expr in ["next weekend", "weekend depan", "akhir pekan depan"] ->
        {sat, sun} = get_next_weekend(base_date)
        {:ok, %{type: "range", start_date: Date.to_iso8601(sat), end_date: Date.to_iso8601(sun)}}

      # relative dates, e.g., "3 days from now", "5 hari lagi", "2 weeks from now"
      Regex.match?(
        ~r/^(\d+)\s+(days?|hari|weeks?|minggu|months?|bulan|years?|tahun)\s+(from now|lagi)$/i,
        expr
      ) ->
        [_, amount_str, unit, _] =
          Regex.run(
            ~r/^(\d+)\s+(days?|hari|weeks?|minggu|months?|bulan|years?|tahun)\s+(from now|lagi)$/i,
            expr
          )

        amount = String.to_integer(amount_str)
        {:ok, calculate_date(base_date, "add", amount, unit)}

      # relative dates in the past, e.g., "3 days ago", "5 hari yang lalu", "2 weeks ago"
      Regex.match?(
        ~r/^(\d+)\s+(days?|hari|weeks?|minggu|months?|bulan|years?|tahun)\s+(ago|yang lalu|lalu)$/i,
        expr
      ) ->
        [_, amount_str, unit, _] =
          Regex.run(
            ~r/^(\d+)\s+(days?|hari|weeks?|minggu|months?|bulan|years?|tahun)\s+(ago|yang lalu|lalu)$/i,
            expr
          )

        amount = String.to_integer(amount_str)
        {:ok, calculate_date(base_date, "subtract", amount, unit)}

      # "next monday", "senin depan"
      String.starts_with?(expr, "next ") or String.ends_with?(expr, " depan") ->
        day_name =
          if String.starts_with?(expr, "next ") do
            String.replace_prefix(expr, "next ", "")
          else
            String.replace_suffix(expr, " depan", "")
          end

        case Map.get(@days, day_name) do
          nil ->
            {:error, "Unknown day name: #{day_name}"}

          target_day ->
            current_day = Date.day_of_week(base_date)
            diff = target_day - current_day
            offset = if diff <= 0, do: diff + 7, else: diff + 7
            target_date = Date.add(base_date, offset)
            {:ok, %{type: "single", date: Date.to_iso8601(target_date)}}
        end

      # "last wednesday", "rabu lalu", "rabu kemarin"
      String.starts_with?(expr, "last ") or String.ends_with?(expr, " lalu") or
        String.ends_with?(expr, " kemarin") or String.ends_with?(expr, " kemaren") ->
        day_name =
          cond do
            String.starts_with?(expr, "last ") ->
              String.replace_prefix(expr, "last ", "")

            String.ends_with?(expr, " lalu") ->
              String.replace_suffix(expr, " lalu", "")

            String.ends_with?(expr, " kemarin") ->
              String.replace_suffix(expr, " kemarin", "")

            String.ends_with?(expr, " kemaren") ->
              String.replace_suffix(expr, " kemaren", "")
          end

        case Map.get(@days, day_name) do
          nil ->
            {:error, "Unknown day name: #{day_name}"}

          target_day ->
            current_day = Date.day_of_week(base_date)
            diff = target_day - current_day
            offset = if diff >= 0, do: diff - 7, else: diff
            target_date = Date.add(base_date, offset)
            {:ok, %{type: "single", date: Date.to_iso8601(target_date)}}
        end

      true ->
        {:error, "Unsupported semantic expression: #{expression}"}
    end
  end

  def calculate_date(base_date, op, amount, unit) do
    multiplier = if op in ["subtract", :subtract], do: -1, else: 1
    total_amount = amount * multiplier

    calculated_date =
      case normalize_unit(unit) do
        "days" ->
          Date.add(base_date, total_amount)

        "weeks" ->
          Date.add(base_date, total_amount * 7)

        "months" ->
          add_months(base_date, total_amount)

        "years" ->
          add_months(base_date, total_amount * 12)
      end

    %{type: "single", date: Date.to_iso8601(calculated_date)}
  end

  defp get_weekend(base_date) do
    day_of_week = Date.day_of_week(base_date)
    saturday_offset = if day_of_week == 7, do: -1, else: 6 - day_of_week
    saturday = Date.add(base_date, saturday_offset)
    sunday = Date.add(saturday, 1)
    {saturday, sunday}
  end

  defp get_next_weekend(base_date) do
    {this_sat, _} = get_weekend(base_date)
    next_sat = Date.add(this_sat, 7)
    next_sun = Date.add(next_sat, 1)
    {next_sat, next_sun}
  end

  defp normalize_unit(unit) do
    u = String.downcase(to_string(unit))

    cond do
      u in ["day", "days", "hari"] -> "days"
      u in ["week", "weeks", "minggu"] -> "weeks"
      u in ["month", "months", "bulan"] -> "months"
      u in ["year", "years", "tahun"] -> "years"
      true -> u
    end
  end

  defp add_months(date, months) do
    year = date.year
    month = date.month
    day = date.day

    total_months = year * 12 + (month - 1) + months
    new_year = div(total_months, 12)
    new_month = rem(total_months, 12) + 1

    days_in_new_month = Calendar.ISO.days_in_month(new_year, new_month)
    new_day = min(day, days_in_new_month)

    Date.new!(new_year, new_month, new_day)
  end
end
