defmodule StellarWeb.Api.InvitationController do
  @moduledoc """
  API undangan **publik** (token-gated, TANPA login) — dipakai halaman accept di
  app Flutter (`/invite?token=...`).

    * `GET  /api/invitations/:token`        → info undangan (email, org) utk prefill
    * `POST /api/invitations/:token/accept` → buat akun teacher {full_name, password}

  Accept user BARU → balas seperti register (`{user, token, refresh_token}`) agar
  klien langsung login. Email yang SUDAH punya akun → hanya di-provision role,
  TANPA token (`is_new_user: false`) → klien arahkan ke login biasa.
  """
  use StellarWeb, :controller

  alias Stellar.Invitations.Service
  alias StellarWeb.Api.UserSerializer

  # GET /api/invitations/:token
  def show(conn, %{"token" => token}) do
    case Service.get_by_token(token) do
      {:ok, inv} ->
        json(conn, %{
          data: %{
            email: to_string(inv.email),
            organization_name: org_name(inv),
            role_key: inv.role_key,
            status: to_string(inv.status)
          }
        })

      {:error, reason} ->
        error(conn, reason)
    end
  end

  # POST /api/invitations/:token/accept
  def accept(conn, %{"token" => token} = params) do
    full_name = string_param(params, "full_name")
    password = string_param(params, "password")

    cond do
      full_name == "" ->
        error(conn, :full_name_required)

      String.length(password) < 8 ->
        error(conn, :password_too_short)

      true ->
        case Service.accept(token, %{full_name: full_name, password: password}) do
          {:ok, %{new: true, user: user, tokens: tokens}} ->
            conn
            |> put_status(:created)
            |> json(%{
              user: UserSerializer.to_json(user),
              token: tokens.token,
              refresh_token: tokens.refresh_token,
              is_new_user: true
            })

          {:ok, %{new: false, user: user}} ->
            json(conn, %{
              user: UserSerializer.to_json(user),
              token: nil,
              refresh_token: nil,
              is_new_user: false,
              message: "existing_account"
            })

          {:error, reason} ->
            error(conn, reason)
        end
    end
  end

  # --- helpers ---

  defp org_name(%{organization: %{name: name}}), do: name
  defp org_name(_), do: nil

  defp string_param(params, key) do
    case Map.get(params, key) do
      v when is_binary(v) -> String.trim(v)
      _ -> ""
    end
  end

  # 404 → tak ada; 410 → tak lagi valid (kedaluwarsa/diterima/dicabut); 422 → sisanya.
  defp error(conn, :not_found), do: send_error(conn, :not_found, "not_found")

  defp error(conn, reason) when reason in [:expired, :already_accepted, :revoked],
    do: send_error(conn, :gone, to_string(reason))

  defp error(conn, reason), do: send_error(conn, :unprocessable_entity, to_string(reason))

  defp send_error(conn, status, msg),
    do: conn |> put_status(status) |> json(%{error: msg})
end
