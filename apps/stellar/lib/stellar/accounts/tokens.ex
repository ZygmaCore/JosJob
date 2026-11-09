defmodule Stellar.Accounts.Tokens do
  @moduledoc """
  Penerbitan & rotasi token untuk API/mobile.

  - **access token**: JWT purpose `:user`, umur 1 jam.
  - **refresh token**: JWT purpose `:refresh` (klaim `token_use = "refresh"`), umur 30 hari.

  `refresh/1` memvalidasi refresh token (tanda tangan + `exp` + belum dicabut),
  menerbitkan pasangan baru, lalu **mencabut** refresh lama (rotasi).
  """
  alias AshAuthentication.Jwt
  alias AshAuthentication.TokenResource
  alias Stellar.Accounts.{Token, User}

  require Logger

  # TTL default (detik): access 1 jam, refresh 30 hari. Bisa di-override lewat
  # config `:stellar, Stellar.Accounts.Tokens` (di-set dari env di runtime.exs).
  @default_access_ttl 3_600
  @default_refresh_ttl 2_592_000

  @doc "Terbitkan pasangan access + refresh untuk `user`."
  @spec issue_pair(User.t()) ::
          {:ok, %{token: String.t(), refresh_token: String.t()}} | {:error, term()}
  def issue_pair(%User{} = user) do
    with {:ok, access, _claims} <-
           Jwt.token_for_user(user, %{}, token_lifetime: access_ttl()),
         {:ok, refresh, _claims} <-
           Jwt.token_for_user(user, %{"token_use" => "refresh"},
             purpose: :refresh,
             token_lifetime: refresh_ttl()
           ) do
      {:ok, %{token: access, refresh_token: refresh}}
    else
      _ -> {:error, :token_generation_failed}
    end
  end

  @doc "TTL access token dalam detik (dari config/env)."
  def access_ttl, do: {ttl(:access_ttl_seconds, @default_access_ttl), :seconds}

  @doc "TTL refresh token dalam detik (dari config/env)."
  def refresh_ttl, do: {ttl(:refresh_ttl_seconds, @default_refresh_ttl), :seconds}

  defp ttl(key, default) do
    :stellar
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key)
    |> case do
      n when is_integer(n) and n > 0 -> n
      _ -> default
    end
  end

  @doc """
  Tukar refresh token dengan pasangan baru (rotasi). Refresh lama dicabut.
  Mengembalikan `{:ok, %{user:, token:, refresh_token:}}` atau `{:error, reason}`.
  """
  @spec refresh(String.t()) :: {:ok, map()} | {:error, term()}
  def refresh(refresh_token) when is_binary(refresh_token) do
    with {:ok, %{"sub" => subject, "token_use" => "refresh"}, _resource} <-
           Jwt.verify(refresh_token, :stellar),
         false <- TokenResource.token_revoked?(Token, refresh_token),
         {:ok, user} <- AshAuthentication.subject_to_user(subject, User),
         {:ok, tokens} <- issue_pair(user) do
      # Rotasi: cabut refresh lama (best-effort — kegagalan cabut tidak menggagalkan refresh).
      _ = revoke(refresh_token)
      {:ok, Map.put(tokens, :user, user)}
    else
      true -> {:error, :revoked}
      {:ok, _claims, _resource} -> {:error, :not_a_refresh_token}
      :error -> {:error, :invalid}
      {:error, reason} -> {:error, reason}
    end
  end

  def refresh(_), do: {:error, :invalid}

  defp revoke(token) do
    TokenResource.revoke(Token, token)
  rescue
    e ->
      Logger.warning("Gagal mencabut refresh token: #{inspect(e)}")
      :error
  end
end
