defmodule JosjobWeb.Api.AuthControllerTest do
  @moduledoc """
  End-to-end HTTP untuk auth mobile Google.

  id_token Google ASLI butuh sign-in Google oleh manusia, jadi di sini kita
  simulasikan: buat RSA key uji, terbitkan id_token BER-BENTUK Google, dan
  suntikkan JWKS + client_id lewat config `Josjob.Accounts.GoogleAuth`. Ini
  menguji jalur penuh: verifikasi id_token -> upsert user -> terbitkan token,
  serta refresh + rotasi — lewat endpoint HTTP sungguhan.
  """
  use JosjobWeb.ConnCase

  alias Josjob.Accounts.GoogleAuth

  @kid "test-key-1"
  @client_id "test-google-client-id.apps.googleusercontent.com"

  setup do
    jwk = JOSE.JWK.generate_key({:rsa, 2048})
    {_, pub} = jwk |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
    pub = Map.merge(pub, %{"kid" => @kid, "alg" => "RS256", "use" => "sig"})

    prev = Application.get_env(:josjob, GoogleAuth, [])

    Application.put_env(:josjob, GoogleAuth,
      client_id: @client_id,
      jwks: %{"keys" => [pub]}
    )

    on_exit(fn -> Application.put_env(:josjob, GoogleAuth, prev) end)

    {:ok, jwk: jwk}
  end

  # Buat id_token bergaya Google, ditandatangani kunci uji. Klaim bisa di-override.
  defp id_token(jwk, overrides \\ %{}) do
    now = System.system_time(:second)

    claims =
      Map.merge(
        %{
          "iss" => "https://accounts.google.com",
          "aud" => @client_id,
          "sub" => "google-sub-#{System.unique_integer([:positive])}",
          "email" => "newuser#{System.unique_integer([:positive])}@example.com",
          "name" => "Test User",
          "email_verified" => true,
          "iat" => now,
          "exp" => now + 3600
        },
        overrides
      )

    {_, token} =
      jwk
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => @kid}, claims)
      |> JOSE.JWS.compact()

    token
  end

  describe "POST /api/auth/google" do
    test "id_token valid -> 200 + user + token + refresh_token, user baru bukan superuser", %{
      conn: conn,
      jwk: jwk
    } do
      conn = post(conn, ~p"/api/auth/google", %{id_token: id_token(jwk), access_token: "ya29.x"})
      body = json_response(conn, 200)

      assert %{"user" => user, "token" => token, "refresh_token" => refresh} = body
      assert is_binary(token) and is_binary(refresh)
      assert user["is_superuser"] == false
      assert String.contains?(user["email"], "@example.com")
    end

    test "email superuser -> is_superuser dipertahankan", %{conn: conn, jwk: jwk} do
      # Superuser di-seed via seeds.exs TIDAK berjalan di sandbox test; buat dulu.
      {:ok, _} =
        Josjob.Accounts.User
        |> Ash.Changeset.for_create(:create, %{
          email: "boss@example.com",
          full_name: "Boss",
          is_superuser: true
        })
        |> Ash.create(authorize?: false)

      token = id_token(jwk, %{"email" => "boss@example.com"})
      conn = post(conn, ~p"/api/auth/google", %{id_token: token})
      body = json_response(conn, 200)
      assert body["user"]["is_superuser"] == true
    end

    test "id_token kadaluarsa -> 401", %{conn: conn, jwk: jwk} do
      now = System.system_time(:second)
      token = id_token(jwk, %{"exp" => now - 10})
      conn = post(conn, ~p"/api/auth/google", %{id_token: token})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "aud salah -> 401", %{conn: conn, jwk: jwk} do
      token = id_token(jwk, %{"aud" => "client-lain.apps.googleusercontent.com"})
      conn = post(conn, ~p"/api/auth/google", %{id_token: token})
      assert json_response(conn, 401)
    end

    test "tanpa id_token -> 400", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/google", %{})
      assert json_response(conn, 400)
    end
  end

  describe "POST /api/auth/refresh" do
    test "refresh valid -> token baru; refresh lama ditolak (rotasi)", %{conn: conn, jwk: jwk} do
      # login dulu untuk dapat refresh_token
      login = post(conn, ~p"/api/auth/google", %{id_token: id_token(jwk)})
      %{"refresh_token" => refresh} = json_response(login, 200)

      # tukar refresh -> pasangan baru
      r1 = post(build_conn(), ~p"/api/auth/refresh", %{refresh_token: refresh})
      body = json_response(r1, 200)
      assert is_binary(body["token"]) and is_binary(body["refresh_token"])
      assert body["refresh_token"] != refresh

      # refresh lama sudah dirotasi -> ditolak
      r2 = post(build_conn(), ~p"/api/auth/refresh", %{refresh_token: refresh})
      assert json_response(r2, 401)
    end

    test "refresh token sampah -> 401", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{refresh_token: "not.a.token"})
      assert json_response(conn, 401)
    end

    test "tanpa refresh_token -> 400", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{})
      assert json_response(conn, 400)
    end
  end
end
