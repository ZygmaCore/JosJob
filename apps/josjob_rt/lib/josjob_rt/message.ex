defmodule JosjobRt.Message do
  @moduledoc "A persisted message belonging to exactly one application or coaching booking."
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field(:application_id, :binary_id)
    field(:booking_id, :binary_id)
    field(:sender_id, :binary_id)
    field(:client_id, :string)
    field(:body, :string)
    field(:sender_name, :string, virtual: true)
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(message, params) do
    message
    |> cast(params, [:body, :client_id])
    |> update_change(:body, fn value ->
      if is_binary(value), do: String.trim(value), else: value
    end)
    |> validate_required([:body, :client_id])
    |> validate_length(:body, max: 4000)
    |> validate_length(:client_id, max: 100)
    |> unique_constraint([:sender_id, :client_id])
    |> check_constraint(:body, name: :message_body_length)
  end
end
