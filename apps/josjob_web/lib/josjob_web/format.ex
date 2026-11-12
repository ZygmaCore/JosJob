defmodule JosjobWeb.Format do
  @moduledoc "Helper format tampilan (dipakai di template admin)."

  @doc "Format datetime jadi string ringkas; nil -> \"-\"."
  def datetime(nil), do: "-"
  def datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
  def datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
  def datetime(_), do: "-"
end
