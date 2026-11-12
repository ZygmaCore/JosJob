defmodule JosjobWeb.Api.AuthController do
  @moduledoc """
  Auth JSON untuk klien mobile (Flutter).

  - `POST /api/auth/register` {full_name, email, password, phone?, address?, birthdate?}
                                                       -> 201 {user, token, refresh_token}
  - `POST /api/auth/login`    {email, password}        -> {user, token, refresh_token}
  - `POST /api/auth/google`   {id_token}               -> {user, token, refresh_token}
  - `POST /api/auth/refresh`  {refresh_token}          -> {token, refresh_token} (rotasi)
  """
  use JosjobWeb, :controller

  require Ash.Query
  alias Josjob.Accounts.{GoogleAuth, Profile, Tokens, User}
  alias Josjob.Accounts.Onboarding

  # Registrasi email + password.
  def register(conn, %{"email" => _, "password" => password, "full_name" => _} = params)
      when is_binary(password) do
    attrs =
      Map.take(params, ["email", "full_name", "phone", "address", "birthdate", "account_type"])

    changeset =
      User
      |> Ash.Changeset.for_create(:register_with_email, Map.put(attrs, "password", password))

    case Ash.create(changeset, authorize?: false) do
      {:ok, user} ->
        {:ok, tokens} = Tokens.issue_pair(user)

        conn
        |> put_status(:created)
        |> json(%{
          user: user_json(user),
          token: tokens.token,
          refresh_token: tokens.refresh_token
        })

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "registrasi gagal", details: error_messages(error)})
    end
  end

  def register(conn, _params),
    do: bad_request(conn, "full_name, email, dan password (min 8) wajib")

  # Login email + password.
  def login(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)

    cond do
      is_nil(user) or is_nil(user.hashed_password) ->
        # Cegah timing attack + jangan bocorkan apakah email ada.
        Bcrypt.no_user_verify()
        unauthorized(conn, "email atau password salah")

      Bcrypt.verify_pass(password, user.hashed_password) ->
        {:ok, tokens} = Tokens.issue_pair(user)

        json(conn, %{
          user: user_json(user),
          token: tokens.token,
          refresh_token: tokens.refresh_token
        })

      true ->
        unauthorized(conn, "email atau password salah")
    end
  end

  def login(conn, _params), do: bad_request(conn, "email dan password wajib")

  # Login/registrasi via id_token Google (SDK mobile).
  def google(conn, %{"id_token" => id_token}) do
    with {:ok, claims} <- GoogleAuth.verify_id_token(id_token),
         {:ok, existing} <- lookup_by_email(claims["email"]),
         {:ok, user} <- GoogleAuth.upsert_user(claims),
         {:ok, tokens} <- Tokens.issue_pair(user) do
      conn
      |> put_status(:ok)
      |> json(%{
        user: user_json(user),
        token: tokens.token,
        refresh_token: tokens.refresh_token,
        # true bila user belum ada sebelum upsert -> klien arahkan ke onboarding.
        is_new_user: is_nil(existing)
      })
    else
      _ -> unauthorized(conn)
    end
  end

  def google(conn, _params), do: bad_request(conn, "id_token wajib")

  # Cek keberadaan user SEBELUM upsert Google (untuk sinyal is_new_user).
  defp lookup_by_email(email) when is_binary(email) and email != "" do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one(authorize?: false)
  end

  defp lookup_by_email(_), do: {:ok, nil}

  # Tukar refresh token dengan pasangan baru (rotasi).
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Tokens.refresh(refresh_token) do
      {:ok, %{user: user, token: token, refresh_token: new_refresh}} ->
        conn
        |> put_status(:ok)
        |> json(%{user: user_json(user), token: token, refresh_token: new_refresh})

      {:error, _reason} ->
        unauthorized(conn)
    end
  end

  def refresh(conn, _params), do: bad_request(conn, "refresh_token wajib")

  # Set tipe akun (personal | organization) untuk user terautentikasi. Dipakai
  # path onboarding Google. Corporation/Institution WAJIB email kantor (422
  # dengan field :email bila ditolak).
  def set_account_type(conn, %{"account_type" => account_type})
      when account_type in ["personal", "organization"] do
    user = conn.assigns.current_user

    case user
         |> Ash.Changeset.for_update(:set_account_type, %{account_type: account_type})
         |> Ash.update(authorize?: false) do
      {:ok, updated} ->
        json(conn, %{user: user_json(updated)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "tipe akun ditolak", details: error_messages(error)})
    end
  end

  def set_account_type(conn, _params),
    do: bad_request(conn, "account_type wajib (personal | organization)")

  # Perbarui progress onboarding (0..100) dan/atau tandai langkah WAJIB selesai,
  # untuk user terautentikasi (Bearer, pipeline :api_auth -> current_user).
  def update_onboarding(conn, params) do
    user = conn.assigns.current_user

    args =
      %{}
      |> then(fn a ->
        case params["progress"] do
          p when is_integer(p) -> Map.put(a, :progress, p)
          _ -> a
        end
      end)
      |> then(fn a ->
        if params["mandatory_completed"] == true,
          do: Map.put(a, :mandatory_completed, true),
          else: a
      end)

    case user
         |> Ash.Changeset.for_update(:update_onboarding, args)
         |> Ash.update(authorize?: false) do
      {:ok, updated} ->
        json(conn, %{user: user_json(updated)})

      {:error, _error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "gagal memperbarui onboarding"})
    end
  end

  # Simpan snapshot jawaban onboarding untuk user terautentikasi (Bearer,
  # pipeline :api_auth -> current_user). Offline-first: klien mengirim
  # `updated_at` (ISO8601) versi kliennya; server pakai LAST-WRITE-WINS —
  # bila updated_at masuk LEBIH LAMA dari yang tersimpan, jawaban tersimpan
  # dipertahankan. Replay payload yang sama = no-op (idempotent).
  def update_answers(conn, %{"answers" => answers, "updated_at" => updated_at})
      when is_map(answers) and is_binary(updated_at) do
    user = conn.assigns.current_user

    with {:ok, incoming_at, _offset} <- DateTime.from_iso8601(updated_at) do
      existing =
        Profile
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one(authorize?: false)

      case existing do
        # Jawaban tersimpan lebih baru -> abaikan tulisan, kembalikan tersimpan.
        {:ok, %Profile{answers_updated_at: stored_at} = profile}
        when not is_nil(stored_at) ->
          if DateTime.compare(incoming_at, stored_at) == :lt do
            json(conn, %{profile: profile_json(profile)})
          else
            upsert_answers(conn, user, answers, incoming_at)
          end

        _ ->
          upsert_answers(conn, user, answers, incoming_at)
      end
    else
      _ -> bad_request(conn, "updated_at wajib ISO8601")
    end
  end

  def update_answers(conn, _params),
    do: bad_request(conn, "answers (map) dan updated_at (ISO8601) wajib")

  defp upsert_answers(conn, user, answers, incoming_at) do
    case Profile
         |> Ash.Changeset.for_create(:upsert_answers, %{
           user_id: user.id,
           answers: answers,
           answers_updated_at: incoming_at
         })
         |> Ash.create(authorize?: false) do
      {:ok, profile} ->
        # Proyeksikan snapshot mentah ke penyimpanan terstruktur per peran akun
        # (worker/graduate -> UserDetail; employer/coordinator -> Organization).
        # Best-effort: kegagalan proyeksi tak menggagalkan penyimpanan Profile.
        Onboarding.Sync.project(user, answers)
        json(conn, %{profile: profile_json(profile)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "gagal menyimpan jawaban", details: error_messages(error)})
    end
  end

  defp profile_json(profile) do
    %{answers: profile.answers, updated_at: profile.answers_updated_at}
  end

  # Bentuk JSON user konsisten (termasuk `roles`) — lihat UserSerializer.
  defp user_json(user), do: JosjobWeb.Api.UserSerializer.to_json(user)

  defp unauthorized(conn, message \\ "unauthorized") do
    conn |> put_status(:unauthorized) |> json(%{error: message})
  end

  defp bad_request(conn, message) do
    conn |> put_status(:bad_request) |> json(%{error: message})
  end

  # Ringkas error Ash jadi list pesan untuk klien.
  defp error_messages(%{errors: errors}) when is_list(errors) do
    Enum.map(errors, fn e ->
      field = Map.get(e, :field) || Map.get(e, :fields)
      msg = if is_exception(e), do: Exception.message(e), else: inspect(e)
      %{field: field, message: msg}
    end)
  end

  defp error_messages(error), do: [%{field: nil, message: Exception.message(error)}]
end
