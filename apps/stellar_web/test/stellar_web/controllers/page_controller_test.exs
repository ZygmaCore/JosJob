defmodule StellarWeb.PageControllerTest do
  use StellarWeb.ConnCase

  test "GET / renders the sign-in page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Sign in with Google"
  end
end
