defmodule JosjobWeb.ChatChannel do
  @moduledoc "Live delivery for the same permission-checked persisted chat exposed by the API."
  use JosjobWeb, :channel
  alias JosjobRt.Chat
  @impl true
  def join("chat:" <> context, _params, socket) do
    with [kind, id] <- String.split(context, ":"),
         expires when is_integer(expires) <- socket.assigns[:token_expires_at],
         true <- expires > System.system_time(:second),
         {:ok, thread} <- Chat.access(socket.assigns.current_user, kind, id) do
      Phoenix.PubSub.subscribe(Josjob.PubSub, Chat.topic(kind, id))

      Process.send_after(
        self(),
        :token_expired,
        min((expires - System.system_time(:second)) * 1000, 86_400_000)
      )

      {:ok, thread, socket |> assign(:kind, kind) |> assign(:context_id, id)}
    else
      _ -> {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:chat_message, message}, socket) do
    case Chat.access(socket.assigns.current_user, socket.assigns.kind, socket.assigns.context_id) do
      {:ok, _} ->
        if socket.assigns.token_expires_at > System.system_time(:second) do
          push(socket, "message_created", message)
          {:noreply, socket}
        else
          {:stop, :normal, socket}
        end

      _ ->
        {:stop, :normal, socket}
    end
  end

  def handle_info(:token_expired, socket), do: {:stop, :normal, socket}
end
