defmodule StellarWeb.ErrorHTMLTest do
  use StellarWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html (halaman custom daisyUI)" do
    html = render_to_string(StellarWeb.ErrorHTML, "404", "html", [])
    assert html =~ "Page not found"
    assert html =~ "btn btn-primary"
  end

  test "renders 500.html" do
    assert render_to_string(StellarWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
