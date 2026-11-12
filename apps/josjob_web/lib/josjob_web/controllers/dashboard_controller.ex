defmodule JosjobWeb.DashboardController do
  @moduledoc """
  Halaman ringkasan (dashboard) untuk user ber-role (selain "default").
  Data DUMMY — hanya contoh tampilan summary (stat cards + pie + bar chart).
  """
  use JosjobWeb, :controller

  def index(conn, _params) do
    pie = dummy_pie()
    bars = dummy_bars()

    render(conn, :index,
      stats: dummy_stats(),
      pie: pie,
      pie_total: Enum.sum(Enum.map(pie, & &1.value)),
      bars: bars,
      bar_max: bars |> Enum.map(& &1.value) |> Enum.max()
    )
  end

  defp dummy_stats do
    [
      %{label: "Total Users", value: "1,248", delta: "+12%", icon: "hero-users"},
      %{label: "Active Courses", value: "86", delta: "+4%", icon: "hero-academic-cap"},
      %{label: "Placements", value: "312", delta: "+9%", icon: "hero-briefcase"},
      %{label: "Completion", value: "74%", delta: "+3%", icon: "hero-chart-bar"}
    ]
  end

  defp dummy_pie do
    [
      %{label: "Employer", value: 35, color: "#6366f1"},
      %{label: "Worker", value: 25, color: "#22c55e"},
      %{label: "Graduate", value: 18, color: "#f59e0b"},
      %{label: "Teacher", value: 14, color: "#ef4444"},
      %{label: "Coordinator", value: 8, color: "#06b6d4"}
    ]
  end

  defp dummy_bars do
    [
      %{label: "Jan", value: 42},
      %{label: "Feb", value: 58},
      %{label: "Mar", value: 50},
      %{label: "Apr", value: 71},
      %{label: "May", value: 64},
      %{label: "Jun", value: 83}
    ]
  end
end
