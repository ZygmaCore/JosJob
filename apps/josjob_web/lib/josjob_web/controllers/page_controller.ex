defmodule JosjobWeb.PageController do
  use JosjobWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
