defmodule JosjobRagpdfWeb.Plugs.Auth do
  @moduledoc """
  Optional shared-secret auth for `/v1/*`.

  If `:api_token` is `nil` or `""`, auth is disabled (local development).
  `/health` and `/` stay public so a load balancer can probe the service.
  """

  @behaviour Plug

  import Plug.Conn

  @public_paths ["/health", "/"]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    token = Application.get_env(:josjob_ragpdf, :api_token)

    cond do
      token in [nil, ""] ->
        conn

      public?(conn.request_path) ->
        conn

      true ->
        case bearer_or_api_key(conn) do
          nil -> unauthorized(conn)
          given -> if Plug.Crypto.secure_compare(given, token), do: conn, else: unauthorized(conn)
        end
    end
  end

  defp public?(path) when is_binary(path), do: path in @public_paths
  defp public?(_), do: false

  defp bearer_or_api_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> blank_to_nil(String.trim(token))
      ["bearer " <> token | _] -> blank_to_nil(String.trim(token))
      _ -> api_key(conn)
    end
  end

  defp api_key(conn) do
    case get_req_header(conn, "x-api-key") do
      [key | _] -> blank_to_nil(String.trim(key))
      _ -> nil
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", "Bearer")
    |> JosjobRagpdfWeb.JSON.send_error(401, "unauthorized", "missing or invalid API token")
    |> halt()
  end
end
