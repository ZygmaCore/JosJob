defmodule JosjobWeb.DemoCvAssetsTest do
  use JosjobWeb.ConnCase, async: true

  test "fictional CV fixtures are downloadable from their seeded URLs", %{conn: conn} do
    for slug <- ~w(backend frontend design data finance hospitality) do
      result = get(conn, "/assets/demo-cvs/#{slug}.pdf")
      assert response(result, 200) |> String.starts_with?("%PDF-")

      assert Enum.any?(
               get_resp_header(result, "content-type"),
               &String.starts_with?(&1, "application/pdf")
             )
    end
  end
end
