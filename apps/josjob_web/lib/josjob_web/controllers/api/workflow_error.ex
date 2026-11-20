defmodule JosjobWeb.Api.WorkflowError do
  @moduledoc false
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def respond(conn, {:error, %Ecto.Changeset{} = changeset}) do
    duplicate? =
      Enum.any?(changeset.errors, fn {_field, {_message, opts}} ->
        opts[:constraint] == :unique
      end)

    duplicate_error =
      if match?(%JosjobRt.Message{}, changeset.data),
        do: "idempotency_conflict",
        else: "already_submitted"

    conn
    |> put_status(if(duplicate?, do: 409, else: 422))
    |> json(%{error: if(duplicate?, do: duplicate_error, else: "validation_failed")})
  end

  def respond(conn, {:error, reason}) when is_atom(reason) do
    status =
      case reason do
        :not_found ->
          404

        :forbidden ->
          403

        :rate_limited ->
          429

        r
        when r in [
               :stale_application,
               :invalid_transition,
               :job_closed,
               :self_application,
               :chat_read_only,
               :idempotency_conflict
             ] ->
          409

        r when r in [:consent_required, :invalid_note, :invalid_interview_date] ->
          422

        _ ->
          400
      end

    conn |> put_status(status) |> json(%{error: reason})
  end
end
