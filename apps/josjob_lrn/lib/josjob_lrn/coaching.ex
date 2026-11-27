defmodule JosjobLrn.Coaching do
  @moduledoc "Independent free one-on-one coaching, with explicit ownership and booking admission."
  use Ash.Domain
  require Ash.Query
  alias Josjob.Repo
  alias JosjobLrn.Coaching.{Profile, Slot, Booking}

  resources do
    resource Profile
    resource Slot
    resource Booking
  end

  def my_profile(user),
    do: Profile |> Ash.Query.filter(user_id == ^user.id) |> Ash.read_one!(authorize?: false)

  def save_profile(user, attrs) do
    attrs = Map.take(attrs, ~w(display_name headline bio expertise session_minutes))

    case my_profile(user) do
      nil ->
        Profile
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.force_change_attribute(:user_id, user.id)
        |> Ash.create(authorize?: false)

      profile ->
        profile |> Ash.Changeset.for_update(:update, attrs) |> Ash.update(authorize?: false)
    end
  end

  def review(user, id, status) when status in ["approved", "suspended", "pending"] do
    if Josjob.Authz.superuser?(user) do
      with {:ok, profile} <- fetch(Profile, id) do
        transact(fn ->
          lock_profile(profile.id)

          profile
          |> Ash.Changeset.for_update(:set_status, %{status: status})
          |> Ash.update!(authorize?: false, return_notifications?: true)
        end)
      end
    else
      {:error, :forbidden}
    end
  end

  def review(_user, _id, _status), do: {:error, :invalid_status}

  def admin_profiles(user) do
    if Josjob.Authz.superuser?(user),
      do: {:ok, Profile |> Ash.Query.sort(created_at: :desc) |> Ash.read!(authorize?: false)},
      else: {:error, :forbidden}
  end

  def create_slot(user, attrs) do
    with %Profile{} = profile <- my_profile(user),
         {:ok, starts_at} <- slot_date(Map.get(attrs, "starts_at")) do
      transact(fn ->
        lock_profile(profile.id)
        profile = Ash.get!(Profile, profile.id, authorize?: false)
        if profile.status == :suspended, do: Repo.rollback(:forbidden)

        if DateTime.compare(starts_at, DateTime.utc_now()) != :gt,
          do: Repo.rollback(:invalid_date)

        ends_at = DateTime.add(starts_at, profile.session_minutes * 60, :second)

        overlap =
          Slot
          |> Ash.Query.filter(
            coach_id == ^profile.id and enabled == true and starts_at < ^ends_at and
              ends_at > ^starts_at
          )
          |> Ash.exists?(authorize?: false)

        if overlap, do: Repo.rollback(:overlap)

        Slot
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.Changeset.force_change_attributes(%{
          coach_id: profile.id,
          starts_at: starts_at,
          ends_at: ends_at
        })
        |> Ash.create!(authorize?: false, return_notifications?: true)
      end)
    else
      nil -> {:error, :profile_required}
      _ -> {:error, :invalid_date}
    end
  end

  def close_slot(user, id) do
    with {:ok, slot} <- fetch(Slot, id),
         %Profile{} = profile <- my_profile(user),
         true <- slot.coach_id == profile.id do
      transact(fn ->
        lock_profile(profile.id)
        if occupied?(slot.id), do: Repo.rollback(:slot_unavailable)

        slot
        |> Ash.Changeset.for_update(:close, %{})
        |> Ash.update!(authorize?: false, return_notifications?: true)
      end)
    else
      {:error, _} = error -> error
      _ -> {:error, :not_found}
    end
  end

  def book(user, slot_id) do
    with {:ok, slot} <- fetch(Slot, slot_id) do
      transact(fn ->
        lock_profile(slot.coach_id)
        Repo.query!("SELECT id FROM users WHERE id::text = $1 FOR UPDATE", [user.id])
        slot = Ash.get!(Slot, slot.id, authorize?: false)
        profile = Ash.get!(Profile, slot.coach_id, authorize?: false)
        if profile.user_id == user.id, do: Repo.rollback(:self_booking)

        if profile.status != :approved or not slot.enabled or
             DateTime.compare(slot.starts_at, DateTime.utc_now()) != :gt or occupied?(slot.id),
           do: Repo.rollback(:slot_unavailable)

        overlap =
          Booking
          |> Ash.Query.filter(
            learner_id == ^user.id and status == :confirmed and starts_at < ^slot.ends_at and
              ends_at > ^slot.starts_at
          )
          |> Ash.exists?(authorize?: false)

        if overlap, do: Repo.rollback(:overlap)

        Booking
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.Changeset.force_change_attributes(%{
          slot_id: slot.id,
          coach_id: profile.id,
          learner_id: user.id,
          starts_at: slot.starts_at,
          ends_at: slot.ends_at
        })
        |> Ash.create!(authorize?: false, return_notifications?: true)
      end)
    end
  end

  def change_booking(user, id, action) when action in ["cancel", "complete"] do
    with {:ok, booking} <- fetch(Booking, id) do
      result =
        transact(fn ->
          lock_profile(booking.coach_id)
          booking = Ash.get!(Booking, id, load: :coach, authorize?: false)
          host = booking.coach.user_id == user.id
          if not host and booking.learner_id != user.id, do: Repo.rollback(:not_found)

          if booking.status == :cancelled and action == "cancel",
            do: {booking, []},
            else: update_booking(booking, action, host)
        end)

      if match?({:ok, _}, result),
        do:
          Phoenix.PubSub.broadcast(
            Josjob.PubSub,
            "coaching_booking:#{id}",
            :coaching_booking_changed
          )

      result
    end
  end

  def change_booking(_user, _id, _action), do: {:error, :invalid_status}

  defp update_booking(booking, action, host) do
    now = DateTime.utc_now()
    if booking.status != :confirmed, do: Repo.rollback(:invalid_status)

    cond do
      action == "complete" and (not host or DateTime.compare(now, booking.ends_at) == :lt) ->
        Repo.rollback(:forbidden)

      action == "cancel" and DateTime.compare(now, booking.ends_at) != :lt ->
        Repo.rollback(:invalid_status)

      true ->
        booking
        |> Ash.Changeset.for_update(:set_status, %{
          status: if(action == "cancel", do: :cancelled, else: :completed)
        })
        |> Ash.update!(authorize?: false, return_notifications?: true)
    end
  end

  def live_role(id, user_id) do
    with {:ok, booking} <- fetch(Booking, id),
         booking <- Ash.load!(booking, :coach, authorize?: false),
         true <- joinable?(booking) do
      cond do
        booking.coach.user_id == user_id -> :host
        booking.learner_id == user_id -> :guest
        true -> nil
      end
    else
      _ -> nil
    end
  end

  def joinable?(booking) do
    now = DateTime.utc_now()

    booking.status == :confirmed and booking.coach.status == :approved and
      DateTime.compare(now, booking.starts_at) != :lt and
      DateTime.compare(now, booking.ends_at) == :lt
  end

  @doc "Approved coaches and their available future slots; no private booking data."
  def available_coaches do
    coaches =
      Profile
      |> Ash.Query.filter(status == :approved)
      |> Ash.Query.sort(display_name: :asc, id: :asc)
      |> Ash.read!(authorize?: false)

    coach_ids = Enum.map(coaches, & &1.id)
    now = DateTime.utc_now()

    slots =
      Slot
      |> Ash.Query.filter(coach_id in ^coach_ids and enabled == true and starts_at > ^now)
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.Query.load(:bookings)
      |> Ash.read!(authorize?: false)

    slots =
      Enum.reject(slots, fn slot -> Enum.any?(slot.bookings, &(&1.status == :confirmed)) end)

    Enum.map(coaches, fn coach ->
      profile_json(coach)
      |> Map.put(
        :slots,
        slots |> Enum.filter(&(&1.coach_id == coach.id)) |> Enum.map(&slot_json/1)
      )
    end)
  end

  def dashboard(user) do
    profile = my_profile(user)
    now = DateTime.utc_now()

    bookings =
      case profile do
        nil -> Booking |> Ash.Query.filter(learner_id == ^user.id)
        profile -> Booking |> Ash.Query.filter(learner_id == ^user.id or coach_id == ^profile.id)
      end

    bookings =
      bookings
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.Query.load([:coach, :learner])
      |> Ash.read!(authorize?: false)

    own_slots =
      if profile do
        Slot
        |> Ash.Query.filter(coach_id == ^profile.id and starts_at > ^now and enabled == true)
        |> Ash.Query.sort(starts_at: :asc)
        |> Ash.Query.load(:bookings)
        |> Ash.read!(authorize?: false)
      else
        []
      end

    %{
      coaches: available_coaches(),
      bookings: Enum.map(bookings, &booking_json(&1, user)),
      my_profile: profile && profile_json(profile),
      my_slots: Enum.map(own_slots, &slot_json/1)
    }
  end

  def profile_json(profile),
    do: %{
      id: profile.id,
      display_name: profile.display_name,
      headline: profile.headline,
      bio: profile.bio,
      expertise: profile.expertise,
      session_minutes: profile.session_minutes,
      status: profile.status,
      price_cents: 0
    }

  def slot_json(slot),
    do: %{
      id: slot.id,
      starts_at: slot.starts_at,
      ends_at: slot.ends_at,
      booked: Enum.any?(slot.bookings, &(&1.status == :confirmed))
    }

  def booking_json(booking, user) do
    host = booking.coach.user_id == user.id

    %{
      id: booking.id,
      coach_name: booking.coach.display_name,
      learner_name: booking.learner.full_name,
      starts_at: booking.starts_at,
      ends_at: booking.ends_at,
      status: booking.status,
      role: if(host, do: "host", else: "guest"),
      can_join: joinable?(booking),
      can_cancel:
        booking.status == :confirmed and
          DateTime.compare(DateTime.utc_now(), booking.ends_at) == :lt,
      can_complete:
        host and booking.status == :confirmed and
          DateTime.compare(DateTime.utc_now(), booking.ends_at) != :lt,
      room_id: "coaching:#{booking.id}:one_on_one",
      price_cents: 0
    }
  end

  defp transact(fun) do
    case Repo.transaction(fun) do
      {:ok, {record, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, record}

      error ->
        error
    end
  end

  defp occupied?(id),
    do:
      Booking
      |> Ash.Query.filter(slot_id == ^id and status == :confirmed)
      |> Ash.exists?(authorize?: false)

  defp slot_date(date) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, date, _offset} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp slot_date(_), do: {:error, :invalid_date}

  defp lock_profile(id),
    do: Repo.query!("SELECT id FROM coaching_profiles WHERE id::text = $1 FOR UPDATE", [id])

  defp fetch(resource, id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         {:ok, item} when not is_nil(item) <- Ash.get(resource, id, authorize?: false) do
      {:ok, item}
    else
      _ -> {:error, :not_found}
    end
  end
end
