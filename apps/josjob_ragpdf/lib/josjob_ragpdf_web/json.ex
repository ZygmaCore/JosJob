defmodule JosjobRagpdfWeb.JSON do
  @moduledoc "Small JSON response helpers shared by the HTTP layer."

  import Plug.Conn

  @doc "Send a `200`-style success body wrapped in `{\"data\": ...}`."
  @spec send_data(Plug.Conn.t(), non_neg_integer(), term()) :: Plug.Conn.t()
  def send_data(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{"data" => data}))
  end

  @doc """
  Send an error body:

      {"error": "...", "message": "...", "fields": {...}}
  """
  @spec send_error(Plug.Conn.t(), non_neg_integer(), String.t(), String.t(), map() | nil) ::
          Plug.Conn.t()
  def send_error(conn, status, error, message, fields \\ nil) do
    payload = %{"error" => error, "message" => message}

    payload =
      if is_map(fields) and map_size(fields) > 0 do
        Map.put(payload, "fields", fields)
      else
        payload
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
  end

  @doc "Send a JSON `404`."
  @spec not_found(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def not_found(conn, message \\ "resource not found") do
    send_error(conn, 404, "not_found", message)
  end
end
