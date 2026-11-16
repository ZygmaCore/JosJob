defmodule Josjob.Accounts.User do
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer],
    domain: Josjob.Accounts

  postgres do
    table("users")
    repo(Josjob.Repo)
  end

  authentication do
    domain(Josjob.Accounts)
    session_identifier(:jti)

    tokens do
      enabled?(true)
      token_resource(Josjob.Accounts.Token)

      signing_secret(fn _, _ ->
        {:ok, Application.fetch_env!(:josjob, :token_signing_secret)}
      end)
    end

    strategies do
      # Login FULL Google OAuth — tidak ada strategi password.
      google do
        # Kredensial dibaca dari config `:josjob, :google_oauth` (di-set dari
        # envs/.env di runtime.exs) supaya konsisten & tanpa export manual.
        client_id(fn _, _ ->
          {:ok,
           Application.get_env(:josjob, :google_oauth, [])[:client_id] || "mock_google_client_id"}
        end)

        client_secret(fn _, _ ->
          {:ok,
           Application.get_env(:josjob, :google_oauth, [])[:client_secret] ||
             "mock_google_client_secret"}
        end)

        redirect_uri(fn _, _ ->
          {:ok,
           Application.get_env(:josjob, :google_oauth, [])[:redirect_uri] ||
             "http://localhost:4000/auth"}
        end)

        register_action_name(:register_with_google)
        identity_resource(Josjob.Accounts.UserIdentity)
        prevent_hijacking?(false)
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:full_name, :string, allow_nil?: false, public?: true)
    attribute(:hashed_password, :string, allow_nil?: true, sensitive?: true)
    attribute(:phone, :string, public?: true)
    attribute(:address, :string, public?: true)
    attribute(:birthdate, :date, public?: true)
    attribute(:avatar_url, :string, public?: true)
    attribute(:confirmed_at, :utc_datetime, public?: true)

    # Tipe registrasi: :personal (individu, email bebas) atau :organization
    # (Corporation/Institution, WAJIB email kantor — lihat EmailDomains).
    # Nil = belum dipilih (mis. sign-in Google baru; tipe dipilih saat
    # onboarding via aksi :set_account_type).
    attribute(:account_type, Josjob.Accounts.AccountType, allow_nil?: true, public?: true)

    # Sudah menyelesaikan langkah WAJIB onboarding ("Who you are")? Klien memakai
    # ini untuk memutuskan onboarding vs dashboard tiap login/Google/reload.
    attribute(:mandatory_completed, :boolean,
      allow_nil?: false,
      default: false,
      public?: true
    )

    # Progress onboarding keseluruhan 0..100 (langkah wajib + langkah opsional).
    # Klien menampilkan kartu progress di dashboard bila < 100.
    attribute(:onboarding_progress, :integer,
      allow_nil?: false,
      default: 0,
      constraints: [min: 0, max: 100],
      public?: true
    )

    # Admin PLATFORM (pengganti superuser via roles). Lihat PRD users_and_roles.
    attribute(:is_superuser, :boolean, allow_nil?: false, default: false, public?: true)

    # Metode registrasi: "email" / "google" / "linkedin". Nullable.
    attribute(:registration_type, :string, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_email, [:email])
  end

  actions do
    default_accept([
      :email,
      :full_name,
      :phone,
      :address,
      :birthdate,
      :avatar_url,
      :confirmed_at,
      :is_superuser,
      :registration_type
    ])

    defaults([:create, :read, :update, :destroy])

    create :register_with_google do
      argument(:user_info, :map, allow_nil?: false)
      argument(:oauth_tokens, :map, allow_nil?: false)

      upsert?(true)
      upsert_identity(:unique_email)

      change(AshAuthentication.GenerateTokenChange)
      change(AshAuthentication.Strategy.OAuth2.IdentityChange)

      change(fn changeset, _ ->
        info = Ash.Changeset.get_argument(changeset, :user_info) || %{}
        get = fn keys -> Enum.find_value(keys, fn k -> Map.get(info, k) end) end

        email = get.(["email", :email])
        # full_name WAJIB (NOT NULL). Dari klaim `name` Google; fallback ke email.
        full_name = get.(["name", :name]) || email
        avatar = get.(["picture", :picture])
        verified? = get.(["email_verified", :email_verified]) == true

        attrs =
          %{email: email, full_name: full_name, registration_type: "google"}
          |> then(fn a -> if avatar, do: Map.put(a, :avatar_url, avatar), else: a end)
          |> then(fn a ->
            if verified?,
              do: Map.put(a, :confirmed_at, DateTime.truncate(DateTime.utc_now(), :second)),
              else: a
          end)

        Ash.Changeset.change_attributes(changeset, attrs)
      end)
    end

    # Registrasi email + password (API mobile). Password di-hash dgn Bcrypt.
    create :register_with_email do
      accept([:email, :full_name, :phone, :address, :birthdate, :account_type])

      argument(:password, :string,
        allow_nil?: false,
        sensitive?: true,
        constraints: [min_length: 8]
      )

      # Corporation/Institution WAJIB email kantor; personal bebas.
      validate(Josjob.Accounts.Validations.WorkEmailForOrganization)

      change(set_attribute(:registration_type, "email"))

      change(fn changeset, _ ->
        case Ash.Changeset.get_argument(changeset, :password) do
          pw when is_binary(pw) ->
            Ash.Changeset.change_attribute(changeset, :hashed_password, Bcrypt.hash_pwd_salt(pw))

          _ ->
            changeset
        end
      end)
    end

    # Flow MOBILE: upsert user dari klaim id_token Google yang sudah diverifikasi
    # di controller. Self-contained (tanpa OAuth2 IdentityChange), cukup by email.
    # User baru -> roles ["default"]; user lama -> roles TIDAK ditimpa (superuser aman).
    create :upsert_with_google_claims do
      upsert?(true)
      upsert_identity(:unique_email)
      accept([])
      argument(:email, :string, allow_nil?: false)
      argument(:full_name, :string, allow_nil?: true)
      argument(:avatar_url, :string, allow_nil?: true)

      change(set_attribute(:registration_type, "google"))
      change(set_attribute(:email, arg(:email)))
      # full_name WAJIB (NOT NULL): pakai argumen bila ada, jika tidak fallback email.
      # avatar_url (dari klaim `picture` Google) di-set bila tersedia.
      change(fn changeset, _ ->
        full_name =
          Ash.Changeset.get_argument(changeset, :full_name) ||
            Ash.Changeset.get_argument(changeset, :email)

        changeset = Ash.Changeset.change_attribute(changeset, :full_name, full_name)

        case Ash.Changeset.get_argument(changeset, :avatar_url) do
          url when is_binary(url) and url != "" ->
            Ash.Changeset.change_attribute(changeset, :avatar_url, url)

          _ ->
            changeset
        end
      end)
    end

    # Tandai langkah wajib onboarding selesai (dipanggil klien lewat
    # POST /api/onboarding/complete setelah layar identitas dikonfirmasi).
    # Perbarui progress onboarding (dan tandai langkah wajib selesai bila diminta).
    update :update_onboarding do
      accept([])
      # Custom change fn (clamping + conditional) can't run atomically.
      require_atomic?(false)
      argument(:progress, :integer, allow_nil?: true)
      argument(:mandatory_completed, :boolean, allow_nil?: true)

      change(fn changeset, _ ->
        changeset =
          case Ash.Changeset.get_argument(changeset, :progress) do
            p when is_integer(p) ->
              Ash.Changeset.change_attribute(changeset, :onboarding_progress, min(100, max(0, p)))

            _ ->
              changeset
          end

        if Ash.Changeset.get_argument(changeset, :mandatory_completed) == true do
          Ash.Changeset.change_attribute(changeset, :mandatory_completed, true)
        else
          changeset
        end
      end)
    end

    # Set/ubah tipe akun. Dipakai path onboarding sign-in Google: user memilih
    # Personal vs Corporation/Institution setelah masuk (email/password sudah
    # menetapkannya saat register). Untuk :organization, email KANTOR divalidasi
    # ulang di sini (email Google user sudah tetap).
    update :set_account_type do
      accept([:account_type])
      # Validasi custom (membaca :email) tidak bisa berjalan atomik.
      require_atomic?(false)

      # Tipe akun dikunci setelah dipilih: aksi ini hanya untuk transisi
      # pertama (nil -> nilai) di path onboarding Google. Menetapkan ulang ke
      # nilai lain ditolak (mencegah personal<->organization di-flip); menetapkan
      # nilai yang sama = no-op.
      change(fn changeset, _ctx ->
        current = changeset.data.account_type
        new = Ash.Changeset.get_attribute(changeset, :account_type)

        if is_nil(current) or current == new do
          changeset
        else
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :account_type,
              message: "account type is already set and cannot be changed"
            )
          )
        end
      end)

      validate(Josjob.Accounts.Validations.WorkEmailForOrganization)
    end
  end

  # RBAC di level AKSI saja (tanpa field-policy) supaya field `current_user` yang
  # dimuat dari sesi tetap terbaca di request biasa.
  policies do
    # Aksi internal ash_authentication (register/sign-in/token) harus lolos.
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    # superuser (platform): akses penuh.
    bypass actor_attribute_equals(:is_superuser, true) do
      authorize_if(always())
    end

    # Registrasi/sign-in via Google OAuth terbuka untuk umum.
    policy action(:register_with_google) do
      authorize_if(always())
    end

    # User terautentikasi boleh baca/ubah profil MILIKNYA sendiri.
    policy action_type([:read, :update]) do
      authorize_if(expr(id == ^actor(:id)))
    end
  end
end
