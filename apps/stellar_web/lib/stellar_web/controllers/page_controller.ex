defmodule StellarWeb.PageController do
  use StellarWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
