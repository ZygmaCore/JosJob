defmodule Josjob.Accounts.GoogleAuth do
  @moduledoc """
  Verifikasi Google **id_token** (OIDC) untuk flow login mobile.

  Langkah: ambil JWKS Google -> cek tanda tangan RS256 pada kunci ber-`kid` yang
  sesuai -> validasi klaim `iss` / `aud` (= GOOGLE_CLIENT_ID) / `exp`. Bila valid,
  kembalikan klaim penting (`sub`, `email`, `name`, `picture`).

  Lalu `upsert_user/1` memetakan klaim ke `Josjob.Accounts.User` (upsert by email).
  """
  alias Josjob.Accounts.User

  require Logger

  @default_certs_url "https://www.googleapis.com/oauth2/v3/certs"
  @issuers ["accounts.google.com", "https://accounts.google.com"]

  # Config: `config :josjob, Josjob.Accounts.GoogleAuth,
  #   client_id: <aud yang divalidasi>, certs_url: <url JWKS>, jwks: <override untuk test>`
  defp cfg, do: Application.get_env(:josjob, __MODULE__, [])
  defp client_id, do: cfg()[:client_id] || System.get_env("GOOGLE_CLIENT_ID")
  defp certs_url, do: cfg()[:certs_url] || @default_certs_url
  defp configured_jwks, do: cfg()[:jwks]

  @doc "Verifikasi id_token Google. `{:ok, claims_map}` atau `{:error, reason}`."
  @spec verify_id_token(String.t()) :: {:ok, map()} | {:error, term()}
  def verify_id_token(id_token) when is_binary(id_token) and id_token != "" do
    with {:ok, %{"kid" => kid, "alg" => "RS256"}} <- peek_header(id_token),
         {:ok, jwk} <- fetch_key(kid),
         {true, %JOSE.JWT{fields: claims}, _jws} <-
           JOSE.JWT.verify_strict(JOSE.JWK.from(jwk), ["RS256"], id_token),
         :ok <- validate_claims(claims) do
      {:ok,
       %{
         "sub" => claims["sub"],
         "email" => claims["email"],
         "name" => claims["name"],
         "picture" => claims["picture"]
       }}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_id_token}
    end
  end

  def verify_id_token(_), do: {:error, :invalid_id_token}

  @doc "Upsert user (by email) dari klaim id_token yang sudah diverifikasi."
  @spec upsert_user(map()) :: {:ok, User.t()} | {:error, term()}
  def upsert_user(%{"email" => email} = claims) when is_binary(email) and email != "" do
    attrs =
      %{email: email}
      |> maybe_put(:full_name, claims["name"])
      |> maybe_put(:avatar_url, claims["picture"])

    User
    |> Ash.Changeset.for_create(:upsert_with_google_claims, attrs)
    |> Ash.create(authorize?: false)
  end

  def upsert_user(_), do: {:error, :missing_email}

  defp maybe_put(map, key, value) when is_binary(value) and value != "",
    do: Map.put(map, key, value)

  defp maybe_put(map, _key, _value), do: map

  # --- internal ---

  defp peek_header(token) do
    case Joken.peek_header(token) do
      {:ok, header} -> {:ok, header}
      _ -> {:error, :bad_header}
    end
  rescue
    _ -> {:error, :bad_header}
  end

  defp fetch_key(kid) do
    case configured_jwks() do
      %{"keys" => keys} -> find_key(keys, kid)
      _ -> fetch_remote_key(kid)
    end
  end

  defp fetch_remote_key(kid) do
    case Req.get(certs_url()) do
      {:ok, %{status: 200, body: %{"keys" => keys}}} ->
        find_key(keys, kid)

      other ->
        Logger.warning("Gagal ambil JWKS Google: #{inspect(other)}")
        {:error, :jwks_fetch_failed}
    end
  end

  defp find_key(keys, kid) do
    case Enum.find(keys, &(&1["kid"] == kid)) do
      nil -> {:error, :signing_key_not_found}
      jwk -> {:ok, jwk}
    end
  end

  defp validate_claims(%{"iss" => iss, "aud" => aud, "exp" => exp}) do
    now = System.system_time(:second)
    client_id = client_id()

    cond do
      iss not in @issuers -> {:error, :bad_issuer}
      is_binary(client_id) and client_id != "" and aud != client_id -> {:error, :bad_audience}
      not is_integer(exp) or exp <= now -> {:error, :expired}
      true -> :ok
    end
  end

  defp validate_claims(_), do: {:error, :invalid_claims}
end
