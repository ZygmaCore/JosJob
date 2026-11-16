defmodule JosjobWeb.Api.LiveCoachingControllerTest do
  use JosjobWeb.ConnCase, async: false
  import Phoenix.ChannelTest
  import JosjobWeb.JobFixtures, only: [auth: 2]
  alias Josjob.Accounts.User
  alias JosjobLrn.Coaching
  alias JosjobLrn.Coaching.Booking

  defp user!(attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          email: "independent#{System.unique_integer([:positive])}@example.com",
          full_name: "Test user"
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  defp attrs,
    do: %{
      "display_name" => "Independent coach",
      "headline" => "Career coaching",
      "bio" => "Career guidance for graduates.",
      "expertise" => ["Interviews"],
      "session_minutes" => 30
    }

  defp dashboard(conn, user),
    do:
      conn
      |> auth(user)
      |> get(~p"/api/me/live-coaching")
      |> json_response(200)
      |> Map.fetch!("data")

  defp slot!(user, start \\ DateTime.add(DateTime.utc_now(), 3600, :second)) do
    {:ok, slot} = Coaching.create_slot(user, %{"starts_at" => DateTime.to_iso8601(start)})
    slot
  end

  setup do
    admin = user!(%{is_superuser: true})
    coach = user!()
    learner = user!()
    {:ok, profile} = Coaching.save_profile(coach, attrs())
    %{admin: admin, coach: coach, learner: learner, profile: profile}
  end

  test "profiles are independent, pending by default, and cannot self-approve through profile fields",
       c do
    assert c.conn |> get(~p"/api/me/live-coaching") |> json_response(401)
    assert dashboard(c.conn, c.learner)["coaches"] == []

    result =
      c.conn
      |> auth(c.coach)
      |> put(
        ~p"/api/coaching/profile",
        Map.merge(attrs(), %{"status" => "approved", "user_id" => c.admin.id})
      )
      |> json_response(200)

    assert result["ok"]
    profile = Coaching.my_profile(c.coach)
    assert profile.status == :pending
    assert profile.user_id == c.coach.id

    assert c.conn
           |> auth(c.coach)
           |> patch(~p"/api/coaching/admin/profiles/#{profile.id}", %{status: "approved"})
           |> json_response(403)

    assert c.conn
           |> auth(c.admin)
           |> patch(~p"/api/coaching/admin/profiles/#{profile.id}", %{status: "approved"})
           |> json_response(200)

    assert [%{"id" => id, "price_cents" => 0}] = dashboard(c.conn, c.learner)["coaches"]
    assert id == profile.id
    refute Map.has_key?(dashboard(c.conn, c.learner), "classes")
  end

  test "learners book free 1-on-1 appointments without a course or organization", c do
    {:ok, _} = Coaching.review(c.admin, c.profile.id, "approved")
    slot = slot!(c.coach)

    assert c.conn
           |> auth(c.learner)
           |> post(~p"/api/coaching/bookings", %{
             slot_id: slot.id,
             learner_id: c.admin.id,
             price_cents: 999,
             status: "completed"
           })
           |> json_response(200)

    assert [%{"role" => "guest", "status" => "confirmed", "price_cents" => 0, "id" => id}] =
             dashboard(c.conn, c.learner)["bookings"]

    booking = Ash.get!(Booking, id, authorize?: false)
    assert booking.learner_id == c.learner.id
    assert booking.starts_at == slot.starts_at
    assert dashboard(c.conn, c.coach)["bookings"] |> hd() |> Map.fetch!("role") == "host"
    assert dashboard(c.conn, c.learner)["coaches"] |> hd() |> Map.fetch!("slots") == []
    assert dashboard(c.conn, user!())["bookings"] == []
  end

  test "slots cannot overlap and booked slots cannot be withdrawn or booked twice", c do
    {:ok, _} = Coaching.review(c.admin, c.profile.id, "approved")
    slot = slot!(c.coach)

    assert {:error, :overlap} =
             Coaching.create_slot(c.coach, %{
               "starts_at" => DateTime.to_iso8601(DateTime.add(slot.starts_at, 60, :second))
             })

    assert {:error, :self_booking} = Coaching.book(c.coach, slot.id)
    assert {:ok, _} = Coaching.book(c.learner, slot.id)
    assert {:error, :slot_unavailable} = Coaching.book(user!(), slot.id)
    assert {:error, :slot_unavailable} = Coaching.close_slot(c.coach, slot.id)
    assert {:error, :not_found} = Coaching.close_slot(c.learner, slot.id)
    assert Coaching.my_profile(c.coach).status == :approved
  end

  test "cancelled appointments release slots; unrelated users cannot change them", c do
    {:ok, _} = Coaching.review(c.admin, c.profile.id, "approved")
    slot = slot!(c.coach)
    {:ok, b} = Coaching.book(c.learner, slot.id)
    assert {:error, :not_found} = Coaching.change_booking(user!(), b.id, "cancel")
    assert {:ok, %{status: :cancelled}} = Coaching.change_booking(c.learner, b.id, "cancel")
    assert {:ok, _} = Coaching.change_booking(c.learner, b.id, "cancel")
    assert {:ok, _} = Coaching.book(user!(), slot.id)
    assert Coaching.live_role(b.id, c.learner.id) == nil
  end

  test "learners cannot double book overlapping appointments with different coaches", c do
    {:ok, _} = Coaching.review(c.admin, c.profile.id, "approved")
    first = slot!(c.coach)
    other = user!()
    {:ok, p} = Coaching.save_profile(other, attrs())
    {:ok, _} = Coaching.review(c.admin, p.id, "approved")
    second = slot!(other, first.starts_at)
    assert {:ok, _} = Coaching.book(c.learner, first.id)
    assert {:error, :overlap} = Coaching.book(c.learner, second.id)
  end

  test "future, disabled, suspended and malformed bookings have no room access", c do
    slot = slot!(c.coach)
    assert {:error, :slot_unavailable} = Coaching.book(c.learner, slot.id)
    {:ok, _} = Coaching.review(c.admin, c.profile.id, "approved")
    {:ok, b} = Coaching.book(c.learner, slot.id)
    assert Coaching.live_role(b.id, c.learner.id) == nil
    assert {:ok, _} = Coaching.review(c.admin, c.profile.id, "suspended")
    assert dashboard(c.conn, c.learner)["coaches"] == []
    assert Coaching.live_role("invalid", c.learner.id) == nil
    assert {:error, :not_found} = Coaching.book(c.learner, "invalid")
  end

  test "booking channel derives roles, rejects spoofing and closes on cancellation", c do
    {:ok, _} = Coaching.review(c.admin, c.profile.id, "approved")
    {:ok, b} = Coaching.book(c.learner, slot!(c.coach).id)

    b
    |> Ash.Changeset.for_update(:set_status, %{})
    |> Ash.Changeset.force_change_attributes(%{
      starts_at: DateTime.add(DateTime.utc_now(), -60, :second),
      ends_at: DateTime.add(DateTime.utc_now(), 600, :second)
    })
    |> Ash.update!(authorize?: false)

    room = "live_room:coaching:#{b.id}:one_on_one"

    make_socket = fn user ->
      socket(JosjobWeb.UserSocket, "test: #{user.id}", %{current_user: user, user_id: user.id})
    end

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(make_socket.(user!()), JosjobWeb.LiveRoomChannel, room, %{
               "mode" => "one_on_one",
               "role" => "host"
             })

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(
               make_socket.(c.learner),
               JosjobWeb.LiveRoomChannel,
               "live_room:coaching:bad:one_on_one",
               %{"mode" => "one_on_one", "role" => "host"}
             )

    assert {:ok, reply, socket} =
             subscribe_and_join(make_socket.(c.learner), JosjobWeb.LiveRoomChannel, room, %{
               "mode" => "one_on_one",
               "role" => "host"
             })

    assert reply.self.role == "guest"

    assert {:ok, host, host_socket} =
             subscribe_and_join(make_socket.(c.coach), JosjobWeb.LiveRoomChannel, room, %{
               "mode" => "one_on_one",
               "role" => "guest"
             })

    assert host.self.role == "host"
    ref = Process.monitor(socket.channel_pid)
    host_ref = Process.monitor(host_socket.channel_pid)
    assert {:ok, _} = Coaching.change_booking(c.learner, b.id, "cancel")
    assert_push "room_ended", %{reason: "booking_unavailable"}
    assert_receive {:DOWN, ^ref, :process, _, :normal}
    assert_receive {:DOWN, ^host_ref, :process, _, :normal}
  end
end
