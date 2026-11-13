defmodule JosjobWeb.PageControllerTest do
  use JosjobWeb.ConnCase

  test "GET / renders the sign-in page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Sign in with Google"
  end
end
