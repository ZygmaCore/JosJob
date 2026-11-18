defmodule JosjobRt.Chat do
  @moduledoc "Shared private chat with authorization rechecked for every read, write and delivery."
  import Ecto.Query
  alias Josjob.Repo
  alias JosjobJob.Applications
  alias JosjobLrn.Coaching.Booking
  alias JosjobRt.Message

  def topic(kind, id), do: "chat_messages:#{kind}:#{id}"

  def access(user, "application", id) do
    with {:ok, application} <- Applications.get(user, id) do
      {:ok,
       %{
         title: application.job_title,
         subtitle: application.company,
         can_send: Applications.active?(application)
       }}
    end
  end

  def access(user, "coaching", id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         {:ok, %Booking{} = booking} <-
           Ash.get(Booking, id, load: [:coach, :learner], authorize?: false),
         true <- user.id in [booking.learner_id, booking.coach.user_id] do
      name =
        if user.id == booking.learner_id,
          do: booking.coach.display_name,
          else: booking.learner.full_name

      {:ok,
       %{
         title: name,
         subtitle: "Coaching appointment",
         can_send:
           booking.status in [:confirmed, :completed] and booking.coach.status == :approved
       }}
    else
      _ -> {:error, :not_found}
    end
  end

  def access(_user, _kind, _id), do: {:error, :not_found}

  def list(user, kind, id, params) do
    with {:ok, thread} <- access(user, kind, id),
         {:ok, before_id} <- cursor(params["before"]) do
      query = scoped(kind, id)
      query = if before_id, do: from(m in query, where: m.id < ^before_id), else: query
      messages = Repo.all(from(m in query, order_by: [desc: m.id], limit: 51))
      more? = length(messages) > 50
      messages = messages |> Enum.take(50) |> Enum.reverse()

      {:ok,
       %{
         thread: Map.put(thread, :self_id, user.id),
         data: Enum.map(messages, &json/1),
         next_before: if(more?, do: to_string(hd(messages).id), else: nil)
       }}
    end
  end

  def send_message(user, kind, id, params) do
    with {:ok, _} <- access(user, kind, id) do
      result =
        Repo.transaction(fn ->
          lock_context(kind, id)

          thread =
            case access(user, kind, id) do
              {:ok, thread} -> thread
              _ -> Repo.rollback(:not_found)
            end

          message =
            case kind do
              "application" -> %Message{application_id: id, sender_id: user.id}
              "coaching" -> %Message{booking_id: id, sender_id: user.id}
            end

          changeset = Message.changeset(message, params)
          if not changeset.valid?, do: Repo.rollback(changeset)
          client_id = Ecto.Changeset.get_field(changeset, :client_id)
          body = Ecto.Changeset.get_field(changeset, :body)

          existing =
            Repo.one(
              from(m in Message, where: m.sender_id == ^user.id and m.client_id == ^client_id)
            )

          cond do
            existing && existing.application_id == message.application_id &&
              existing.booking_id == message.booking_id && existing.body == body ->
              {existing, false}

            existing ->
              Repo.rollback(:idempotency_conflict)

            not thread.can_send ->
              Repo.rollback(:chat_read_only)

            true ->
              since = DateTime.add(DateTime.utc_now(), -60, :second)

              recent =
                Repo.aggregate(
                  from(m in Message, where: m.sender_id == ^user.id and m.inserted_at >= ^since),
                  :count
                )

              if recent >= 30, do: Repo.rollback(:rate_limited)

              case Repo.insert(changeset) do
                {:ok, saved} -> {saved, true}
                {:error, error} -> Repo.rollback(error)
              end
          end
        end)

      case result do
        {:ok, {message, new?}} ->
          message = %{message | sender_name: user.full_name} |> json()

          if new?,
            do: Phoenix.PubSub.broadcast(Josjob.PubSub, topic(kind, id), {:chat_message, message})

          {:ok, message}

        error ->
          error
      end
    end
  end

  defp scoped(kind, id) do
    query =
      from(m in Message,
        join: u in "users",
        on: u.id == m.sender_id,
        select_merge: %{sender_name: u.full_name}
      )

    case kind do
      "application" -> from(m in query, where: m.application_id == ^id)
      "coaching" -> from(m in query, where: m.booking_id == ^id)
    end
  end

  defp lock_context("application", id),
    do:
      Repo.query!("SELECT id FROM job_applications WHERE id = $1::uuid FOR UPDATE", [
        Ecto.UUID.dump!(id)
      ])

  defp lock_context("coaching", id) do
    uuid = Ecto.UUID.dump!(id)

    Repo.query!(
      "SELECT id FROM coaching_profiles WHERE id = (SELECT coach_id FROM coaching_bookings WHERE id = $1::uuid) FOR UPDATE",
      [uuid]
    )

    Repo.query!("SELECT id FROM coaching_bookings WHERE id = $1::uuid FOR UPDATE", [uuid])
  end

  defp json(message),
    do: %{
      id: to_string(message.id),
      sender_id: message.sender_id,
      sender_name: message.sender_name,
      body: message.body,
      client_id: message.client_id,
      created_at: message.inserted_at
    }

  defp cursor(nil), do: {:ok, nil}

  defp cursor(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 and n < 9_223_372_036_854_775_807 -> {:ok, n}
      _ -> {:error, :invalid_cursor}
    end
  end

  defp cursor(_), do: {:error, :invalid_cursor}
end
