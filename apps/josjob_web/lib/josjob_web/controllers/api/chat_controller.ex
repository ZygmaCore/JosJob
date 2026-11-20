defmodule JosjobWeb.Api.ChatController do
  use JosjobWeb, :controller
  alias JosjobRt.Chat
  alias JosjobWeb.Api.WorkflowError

  def index(conn, %{"kind" => kind, "id" => id} = params) do
    case Chat.list(conn.assigns.current_user, kind, id, params) do
      {:ok, result} -> json(conn, result)
      error -> WorkflowError.respond(conn, error)
    end
  end

  def create(conn, %{"kind" => kind, "id" => id} = params) do
    case Chat.send_message(conn.assigns.current_user, kind, id, params) do
      {:ok, message} -> conn |> put_status(201) |> json(%{data: message})
      error -> WorkflowError.respond(conn, error)
    end
  end
end
