defmodule StellarWeb.Api.EnrollmentController do
  @moduledoc """
  Enrollment student (Bearer). FREE courses enrol in one call; PAID courses go
  through Stripe: `create_intent` mints a PaymentIntent (amount from the course),
  the client confirms the card, then `confirm` verifies the payment succeeded
  server-side before granting the enrolment. Capacity & double-enrol are checked
  explicitly (409) + domain backstop.
  """
  use StellarWeb, :controller

  require Ash.Query
  require Logger

  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Class, Enrollment}
  alias Stellar.Payments.{Billing, Sync}
  alias Stellar.Payments.Stripe.Client
  alias StellarWeb.Api.StudentScope
  alias StellarWeb.Enrollments

  # POST /api/classes/:id/enroll — FREE courses only (paid ⇒ 402 payment_required).
  def create(conn, %{"id" => class_id}) do
    user = conn.assigns.current_user

    with {:ok, class} <- visible_class(conn, class_id),
         :free <- free_or_paid(class.course),
         :ok <- not_already_enrolled(class_id, user.id),
         :ok <- has_seat(class_id) do
      enroll_now(conn, class_id, user, false)
    else
      {:halt, %Plug.Conn{} = c} -> c
      {:paid, course} -> payment_required(conn, course)
      {:halt, :already_enrolled} -> conflict(conn, "already_enrolled")
      {:halt, :full} -> conflict(conn, "full")
    end
  end

  # POST /api/classes/:id/enroll/intent — FREE ⇒ enrol now ({free:true,...});
  # PAID ⇒ create a Stripe PaymentIntent (server-priced) and return its secret.
  def create_intent(conn, %{"id" => class_id}) do
    user = conn.assigns.current_user

    with {:ok, class} <- visible_class(conn, class_id),
         :ok <- not_already_enrolled(class_id, user.id),
         :ok <- has_seat(class_id) do
      course = class.course

      if paid?(course),
        do: start_payment(conn, class_id, course, user),
        else: enroll_now(conn, class_id, user, true)
    else
      {:halt, %Plug.Conn{} = c} -> c
      {:halt, :already_enrolled} -> conflict(conn, "already_enrolled")
      {:halt, :full} -> conflict(conn, "full")
    end
  end

  # POST /api/classes/:id/enroll/confirm {payment_intent_id} — verify the payment
  # succeeded (and belongs to this user + class) server-side, then enrol.
  def confirm(conn, %{"id" => class_id, "payment_intent_id" => pi_id})
      when is_binary(pi_id) do
    user = conn.assigns.current_user

    case visible_class(conn, class_id) do
      {:halt, %Plug.Conn{} = c} ->
        c

      {:ok, _class} ->
        case Billing.get_payment_intent(pi_id) do
          {:ok, pi} -> verify_and_enroll(conn, pi, class_id, user)
          {:error, reason} -> payment_error(conn, reason)
        end
    end
  end

  def confirm(conn, _params), do: bad_request(conn, "payment_intent_id wajib")

  # DELETE /api/classes/:id/enroll
  def delete(conn, %{"id" => class_id}) do
    user = conn.assigns.current_user

    enrollment =
      Enrollment
      |> Ash.Query.filter(class_id == ^class_id and student_id == ^user.id)
      |> Ash.read!(authorize?: false)
      |> List.first()

    case enrollment do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_enrolled"})

      enr ->
        Ash.destroy!(enr, authorize?: false)
        json(conn, %{data: %{ok: true}})
    end
  end

  # GET /api/me/enrollments
  def index(conn, _params) do
    user = conn.assigns.current_user

    enrollments =
      Enrollment
      |> Ash.Query.filter(student_id == ^user.id)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load(class: [:course])
      |> Ash.read!(authorize?: false)

    json(conn, %{data: Enum.map(enrollments, &enrollment_json/1)})
  end

  # --- paid flow helpers ---

  defp start_payment(conn, class_id, course, user) do
    case Billing.create_payment_intent(user, %{
           amount: course.price_cents,
           currency: course.currency,
           description: course.title,
           metadata: %{"class_id" => class_id, "course_id" => course.id}
         }) do
      {:ok, result} ->
        json(conn, %{
          free: false,
          client_secret: result.client_secret,
          payment_intent_id: result.payment_intent_id,
          publishable_key: Client.publishable_key(),
          amount_cents: course.price_cents,
          currency: course.currency
        })

      {:error, reason} ->
        payment_error(conn, reason)
    end
  end

  defp verify_and_enroll(conn, pi, class_id, user) do
    meta = pi["metadata"] || %{}

    cond do
      pi["status"] != "succeeded" ->
        conn
        |> put_status(:payment_required)
        |> json(%{error: "payment_not_completed", status: pi["status"]})

      meta["user_id"] != user.id or meta["class_id"] != class_id ->
        conn |> put_status(:forbidden) |> json(%{error: "payment_mismatch"})

      true ->
        # Mirror the paid Payment locally (best-effort), then grant the enrolment.
        Sync.sync_payment(pi)
        enroll_now(conn, class_id, user, false)
    end
  end

  # Create the enrolment (idempotent). [free_flag] adds `free: true` to the body
  # so the intent endpoint can tell the client no payment was needed.
  defp enroll_now(conn, class_id, user, free_flag) do
    case Enrollments.fulfill(class_id, user.id) do
      {:ok, enr} ->
        data = %{enrollment_id: enr.id, class_id: class_id, status: enr.status}
        payload = if free_flag, do: %{free: true, data: data}, else: %{data: data}
        conn |> put_status(:created) |> json(payload)

      {:error, :full} ->
        conflict(conn, "full")

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid"})
    end
  end

  # --- guards ---

  # Kelas bisa di-enroll bila ada di org tempat user jadi member, ATAU course-nya
  # publik & aktif — konsisten dengan katalog: yang publik bisa dilihat siapa saja
  # jadi juga bisa didaftari (individual learner tanpa org tetap bisa enroll).
  defp visible_class(conn, class_id) do
    org_ids = StudentScope.org_ids(conn.assigns.current_user)

    case Ash.get(Class, class_id, load: [:course], authorize?: false) do
      {:ok, %Class{organization_id: org_id, course: course} = class} ->
        if org_id in org_ids or public_course?(course),
          do: {:ok, class},
          else: {:halt, not_found(conn)}

      _ ->
        {:halt, not_found(conn)}
    end
  end

  defp public_course?(%{is_active: true, is_public: true}), do: true
  defp public_course?(_), do: false

  defp paid?(course), do: not is_nil(course.price_cents) and course.price_cents > 0
  defp free_or_paid(course), do: if(paid?(course), do: {:paid, course}, else: :free)

  defp not_already_enrolled(class_id, user_id) do
    exists? =
      Enrollment
      |> Ash.Query.filter(class_id == ^class_id and student_id == ^user_id)
      |> Ash.read!(authorize?: false)
      |> Enum.any?()

    if exists?, do: {:halt, :already_enrolled}, else: :ok
  end

  defp has_seat(class_id) do
    case Learning.seats_left(class_id) do
      nil -> :ok
      n when n > 0 -> :ok
      _ -> {:halt, :full}
    end
  end

  defp payment_required(conn, course) do
    conn
    |> put_status(:payment_required)
    |> json(%{
      error: "payment_required",
      amount_cents: course.price_cents,
      currency: course.currency
    })
  end

  defp conflict(conn, code), do: conn |> put_status(:conflict) |> json(%{error: code})
  defp bad_request(conn, msg), do: conn |> put_status(:bad_request) |> json(%{error: msg})

  defp payment_error(conn, reason) do
    Logger.warning("Enroll payment error: #{inspect(reason)}")
    conn |> put_status(:unprocessable_entity) |> json(%{error: "payment_failed"})
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp enrollment_json(e) do
    %{
      id: e.id,
      status: e.status,
      enrolled_at: e.enrolled_at,
      class:
        e.class &&
          %{
            id: e.class.id,
            title: e.class.title,
            schedule: e.class.schedule,
            course: e.class.course && %{id: e.class.course.id, title: e.class.course.title}
          }
    }
  end
end
