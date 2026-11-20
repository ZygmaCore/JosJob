defmodule JosjobWeb.Api.ChatControllerTest do
  use JosjobWeb.ConnCase, async: false
  import Phoenix.ChannelTest
  import JosjobWeb.JobFixtures
  alias Josjob.Repo
  alias JosjobJob.Applications
  alias JosjobLrn.Coaching
  alias JosjobRt.{Chat, Message}

  setup do
    employer = user!()
    candidate = user!()
    org = organization!(employer)
    membership = grant!(employer, org, "employer")
    grant!(candidate, org, "graduate")
    job = job!(org, employer)
    {:ok, application} = Applications.submit(candidate, job.id, %{"consent" => true})
    %{employer: employer, candidate: candidate, application: application, membership: membership}
  end

  defp send!(c, user, kind, id, body, client_id \\ Ecto.UUID.generate()) do
    c.conn
    |> auth(user)
    |> post(~p"/api/chats/#{kind}/#{id}/messages", %{
      body: body,
      client_id: client_id,
      sender_id: c.employer.id
    })
    |> json_response(201)
    |> Map.fetch!("data")
  end

  test "hiring messages persist for both sides and cannot be read by an unrelated user", c do
    message = send!(c, c.candidate, "application", c.application.id, "  Hello hiring team  ")
    assert message["body"] == "Hello hiring team"
    assert message["sender_id"] == c.candidate.id

    history =
      c.conn
      |> auth(c.employer)
      |> get(~p"/api/chats/application/#{c.application.id}/messages")
      |> json_response(200)

    assert [%{"id" => id}] = history["data"]
    assert id == message["id"]
    assert history["thread"]["self_id"] == c.employer.id
    assert history["thread"]["can_send"]
    stranger = user!()

    assert c.conn
           |> auth(stranger)
           |> get(~p"/api/chats/application/#{c.application.id}/messages")
           |> json_response(404)

    assert c.conn
           |> auth(stranger)
           |> post(~p"/api/chats/application/#{c.application.id}/messages", %{
             body: "intrusion",
             client_id: "x"
           })
           |> json_response(404)

    assert c.conn
           |> get(~p"/api/chats/application/#{c.application.id}/messages")
           |> json_response(401)
  end

  test "retrying a message is idempotent, and a reused key cannot change its content", c do
    first = send!(c, c.candidate, "application", c.application.id, "Hello", "retry-1")
    second = send!(c, c.candidate, "application", c.application.id, "Hello", "retry-1")
    assert first["id"] == second["id"]
    assert Repo.aggregate(Message, :count) == 1

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/chats/application/#{c.application.id}/messages", %{
             body: "Changed",
             client_id: "retry-1"
           })
           |> json_response(409)

    for params <- [%{body: " "}, %{body: String.duplicate("x", 4001)}, %{body: ["invalid"]}] do
      assert c.conn
             |> auth(c.candidate)
             |> post(
               ~p"/api/chats/application/#{c.application.id}/messages",
               Map.put(params, :client_id, Ecto.UUID.generate())
             )
             |> json_response(422)
    end
  end

  test "history is chronological, bounded and can page back without dropping or duplicating messages",
       c do
    for n <- 1..55 do
      Repo.insert!(%Message{
        application_id: c.application.id,
        sender_id: c.candidate.id,
        client_id: "history-#{n}",
        body: "Message #{n}"
      })
    end

    {:ok, latest} = Chat.list(c.candidate, "application", c.application.id, %{})

    {:ok, previous} =
      Chat.list(c.candidate, "application", c.application.id, %{"before" => latest.next_before})

    assert length(latest.data) == 50
    assert length(previous.data) == 5
    assert previous.next_before == nil
    ids = Enum.map(previous.data ++ latest.data, &String.to_integer(&1.id))
    assert ids == Enum.sort(Enum.uniq(ids))

    assert {:error, :invalid_cursor} =
             Chat.list(c.candidate, "application", c.application.id, %{"before" => "bad"})
  end

  test "withdrawn applications keep chat history and reject new messages", c do
    first = send!(c, c.candidate, "application", c.application.id, "Hello", "before-withdrawal")

    {:ok, _} =
      Applications.advance(c.candidate, c.application.id, %{
        "status" => "withdrawn",
        "expected_status" => "applied"
      })

    {:ok, history} = Chat.list(c.employer, "application", c.application.id, %{})
    refute history.thread.can_send
    assert [%{body: "Hello"}] = history.data

    assert {:error, :chat_read_only} =
             Chat.send_message(c.employer, "application", c.application.id, %{
               "body" => "Late",
               "client_id" => "late"
             })

    retry = send!(c, c.candidate, "application", c.application.id, "Hello", "before-withdrawal")
    assert retry["id"] == first["id"]
  end

  test "coaching chat belongs to the booked learner and coach, with cancelled bookings read-only",
       c do
    coach = user!()

    admin =
      Josjob.Accounts.User
      |> Ash.Changeset.for_create(:create, %{
        email: "chat-admin-#{System.unique_integer([:positive])}@example.com",
        full_name: "Admin",
        is_superuser: true
      })
      |> Ash.create!(authorize?: false)

    {:ok, profile} =
      Coaching.save_profile(coach, %{
        "display_name" => "Career coach",
        "headline" => "Interview guidance",
        "bio" => "We prepare together.",
        "expertise" => ["Interviews"],
        "session_minutes" => 30
      })

    {:ok, _} = Coaching.review(admin, profile.id, "approved")

    {:ok, slot} =
      Coaching.create_slot(coach, %{
        "starts_at" => DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_iso8601()
      })

    {:ok, booking} = Coaching.book(c.candidate, slot.id)
    send!(c, c.candidate, "coaching", booking.id, "Could we practice interviews?")
    {:ok, history} = Chat.list(coach, "coaching", booking.id, %{})
    assert [%{body: "Could we practice interviews?"}] = history.data
    assert {:error, :not_found} = Chat.list(c.employer, "coaching", booking.id, %{})
    assert {:error, :not_found} = Chat.list(admin, "coaching", booking.id, %{})
    {:ok, _} = Coaching.change_booking(coach, booking.id, "cancel")
    {:ok, history} = Chat.list(c.candidate, "coaching", booking.id, %{})
    refute history.thread.can_send

    assert {:error, :chat_read_only} =
             Chat.send_message(coach, "coaching", booking.id, %{
               "body" => "Late",
               "client_id" => "cancelled"
             })

    assert {:error, :not_found} = Chat.list(coach, "coaching", "invalid", %{})
  end

  test "live channel delivers persisted messages only to authorized participants", c do
    socket =
      socket(JosjobWeb.UserSocket, "test-chat", %{
        current_user: c.candidate,
        user_id: c.candidate.id,
        token_expires_at: System.system_time(:second) + 3600
      })

    assert {:ok, _, _} =
             subscribe_and_join(
               socket,
               JosjobWeb.ChatChannel,
               "chat:application:#{c.application.id}"
             )

    send!(c, c.employer, "application", c.application.id, "Let us discuss your application.")
    assert_push "message_created", %{body: "Let us discuss your application."}
    stranger = user!()

    private =
      socket(JosjobWeb.UserSocket, "stranger-chat", %{
        current_user: stranger,
        token_expires_at: System.system_time(:second) + 3600
      })

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(
               private,
               JosjobWeb.ChatChannel,
               "chat:application:#{c.application.id}"
             )

    expired =
      socket(JosjobWeb.UserSocket, "expired-chat", %{
        current_user: c.candidate,
        token_expires_at: System.system_time(:second) - 1
      })

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(
               expired,
               JosjobWeb.ChatChannel,
               "chat:application:#{c.application.id}"
             )
  end

  test "a revoked hiring member is disconnected before the next message is delivered", c do
    socket =
      socket(JosjobWeb.UserSocket, "employer-chat", %{
        current_user: c.employer,
        token_expires_at: System.system_time(:second) + 3600
      })

    {:ok, _, joined} =
      subscribe_and_join(socket, JosjobWeb.ChatChannel, "chat:application:#{c.application.id}")

    pid = joined.channel_pid
    ref = Process.monitor(pid)

    c.membership
    |> Ash.Changeset.for_update(:update, %{status: :suspended})
    |> Ash.update!(authorize?: false)

    send!(c, c.candidate, "application", c.application.id, "Private after revocation")
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    refute_push "message_created", _
    assert {:error, :not_found} = Chat.list(c.employer, "application", c.application.id, %{})
  end
end
