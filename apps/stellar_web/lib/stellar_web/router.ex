defmodule StellarWeb.Router do
  use StellarWeb, :router
  use AshAuthentication.Phoenix.Router
  import AshAuthentication.Plug.Helpers, only: [set_actor: 2]

  # Umbrella: resource auth ada di app `:stellar`, bukan `:stellar_web`. Plug
  # `load_from_session` bawaan mencari resource di otp_app router (:stellar_web)
  # -> kosong -> current_user nil. Muat sesi dari otp_app :stellar.
  def load_stellar_user(conn, _opts),
    do: AshAuthentication.Plug.Helpers.retrieve_from_session(conn, :stellar, [])

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StellarWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Muat current_user dari sesi (otp_app :stellar, lihat load_stellar_user/2).
    plug :load_stellar_user
    # Set actor Ash = current_user, agar policy resource berbasis actor bekerja.
    plug :set_actor, :user
    # Set org aktif + izin efektif (conn.assigns.active_organization_id/:permissions).
    plug StellarWeb.Plugs.AssignActiveOrg
  end

  pipeline :require_admin do
    plug StellarWeb.Plugs.RequireAdmin
  end

  # Gate berbasis permission (RBAC). Butuh AssignActiveOrg (di :browser).
  pipeline :require_orgs_read do
    plug StellarWeb.Plugs.RequirePermission, "organizations:read"
  end

  pipeline :require_members_read do
    # Akses area memberships: cukup punya read ATAU manage (aksi tulis dicek di controller).
    plug StellarWeb.Plugs.RequirePermission, ["members:read", "members:manage"]
  end

  pipeline :require_courses_read do
    # Akses area course: cukup punya salah satu permission course apa pun
    # (read/create/update/delete/manage). `manage` = superset.
    plug StellarWeb.Plugs.RequirePermission,
         ["courses:read", "courses:create", "courses:update", "courses:delete", "courses:manage"]
  end

  pipeline :require_documents_manage do
    plug StellarWeb.Plugs.RequirePermission, "documents:manage"
  end

  pipeline :require_enrollments_read do
    plug StellarWeb.Plugs.RequirePermission,
         [
           "enrollments:read",
           "enrollments:create",
           "enrollments:update",
           "enrollments:delete",
           "enrollments:manage"
         ]
  end

  pipeline :require_classes_read do
    # Akses area class: punya salah satu permission class/enrollment apa pun.
    plug StellarWeb.Plugs.RequirePermission,
         [
           "classes:read",
           "classes:create",
           "classes:update",
           "classes:delete",
           "classes:manage",
           "enrollments:read",
           "enrollments:create",
           "enrollments:update",
           "enrollments:delete",
           "enrollments:manage"
         ]
  end

  pipeline :require_teachers_read do
    plug StellarWeb.Plugs.RequirePermission, ["teachers:read", "teachers:manage"]
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Akses area member (dashboard): wajib login + punya role selain "default".
  pipeline :require_member do
    plug StellarWeb.Plugs.RequireMember
  end

  # Auth API klien mobile via Bearer access token (endpoint pembayaran, dll).
  pipeline :api_auth do
    plug StellarWeb.Plugs.ApiAuth
  end

  # Gate API superuser (setelah :api_auth). Untuk endpoint admin JSON (undangan teacher).
  pipeline :require_superuser_api do
    plug StellarWeb.Plugs.RequireSuperuserApi
  end

  scope "/", StellarWeb do
    pipe_through :browser

    # Halaman utama = login (tombol "Sign in with Google").
    get "/", SessionController, :new

    # Logout INSTAN: GET /sign-out hapus sesi + redirect ke "/".
    get "/sign-out", AuthController, :sign_out
    auth_routes(AuthController, Stellar.Accounts.User, path: "/auth")
  end

  # API JSON untuk klien mobile (Flutter) — login FULL Google OAuth + refresh.
  scope "/api", StellarWeb.Api do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/google", AuthController, :google
    post "/auth/refresh", AuthController, :refresh

    # Undangan teacher — PUBLIK (token-gated, tanpa login): halaman accept Flutter.
    get "/invitations/:token", InvitationController, :show
    post "/invitations/:token/accept", InvitationController, :accept

    # Data referensi publik.
    get "/industries", IndustryController, :index
    get "/countries", CountryController, :index
    get "/skills", SkillController, :index
    get "/professions", ProfessionController, :index

    # Onboarding — butuh Bearer access token (progress + tandai langkah wajib).
    scope "/onboarding" do
      pipe_through :api_auth

      post "/progress", AuthController, :update_onboarding
      # Set tipe akun (personal | organization) — path onboarding Google.
      post "/account-type", AuthController, :set_account_type
      # Simpan snapshot jawaban onboarding (offline-first, last-write-wins).
      put "/answers", AuthController, :update_answers
    end

    # Webhook Stripe — TANPA auth user; keaslian diverifikasi via signature.
    post "/webhooks/stripe", StripeWebhookController, :handle

    # Pembayaran — butuh Bearer access token (pipeline :api_auth).
    scope "/payments" do
      pipe_through :api_auth

      get "/config", PaymentController, :config
      post "/payment-intents", PaymentController, :create_payment_intent
      post "/checkout", PaymentController, :create_checkout_session
      post "/subscriptions", PaymentController, :create_subscription
      delete "/subscriptions/:id", PaymentController, :cancel_subscription
    end

    # Katalog student (Bearer).
    scope "/catalog" do
      pipe_through :api_auth

      get "/courses", CatalogController, :index
      get "/courses/:id", CatalogController, :show
    end

    # VOD sebagai dokumen (Bearer) — upload video via Cloudflare Stream lalu
    # simpan sebagai StellarDoc.Document (bukan lecture).
    scope "/vod" do
      pipe_through :api_auth

      post "/documents/upload-url", VodDocumentController, :create_upload
      post "/documents", VodDocumentController, :create
      get "/documents/:uid/status", VodDocumentController, :status
    end

    # Dokumen + akses (share ala Google Docs) — Bearer. Lihat dokumen yang bisa
    # diakses; pemilik/admin-org kelola daftar share (email + masa berlaku).
    scope "/documents" do
      pipe_through :api_auth

      # Upload dokumen non-video (pdf/doc): mint presigned URL lalu simpan Document.
      post "/upload-url", DocumentController, :create_upload
      post "/", DocumentController, :create

      get "/", DocumentController, :index
      get "/:id", DocumentController, :show
      get "/:id/grants", DocumentController, :grants_index
      post "/:id/grants", DocumentController, :create_grant
      delete "/:id/grants/:grant_id", DocumentController, :delete_grant
    end

    # Enrollment student (Bearer).
    scope "/" do
      pipe_through :api_auth

      post "/classes/:id/enroll", EnrollmentController, :create
      # Paid enrolment: mint a Stripe PaymentIntent, then confirm it server-side.
      post "/classes/:id/enroll/intent", EnrollmentController, :create_intent
      post "/classes/:id/enroll/confirm", EnrollmentController, :confirm
      delete "/classes/:id/enroll", EnrollmentController, :delete
      get "/me/enrollments", EnrollmentController, :index

      # Kelas yang diampu instructor (teacher) — untuk memulai sesi live per-kelas.
      get "/me/classes", ClassController, :index
    end
  end

  # API admin JSON (superuser only, Bearer) — manajemen undangan teacher + daftar org.
  scope "/api/admin", StellarWeb.Api.Admin do
    pipe_through [:api, :api_auth, :require_superuser_api]

    get "/teacher-invitations", InvitationController, :index
    post "/teacher-invitations", InvitationController, :create
    post "/teacher-invitations/:id/resend", InvitationController, :resend

    get "/organizations", OrganizationController, :index
  end

  # Dashboard: ringkasan data untuk semua user ber-role (selain "default").
  scope "/", StellarWeb do
    pipe_through [:browser, :require_member]

    get "/dashboard", DashboardController, :index

    ash_authentication_live_session :member_live do
      live "/rag", RagLive, :index
    end

    # Ganti organisasi aktif (org switcher).
    post "/switch-org", OrgSwitchController, :update

    # Portal dokumen milik user (bank dokumen) — lihat visible_to + unggah/hapus.
    # LiveView; hook :require_member (padanan plug) + :assign_org (layout/nav).
    ash_authentication_live_session :my_documents_live,
      on_mount: [
        {StellarWeb.LiveAuth, :require_member},
        {StellarWeb.LiveAuth, :assign_org}
      ] do
      live "/my/documents", MyDocumentLive, :index
      live "/my/documents/new", MyDocumentLive, :new
    end
  end

  # Kelola data. Users management (Ash-native) — superuser only.
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_admin]

    # Menu LiveView (pola pilot Skills) — satu halaman (list + interaksi live),
    # form New/Edit di modal via live_action. Gate ganda: pipeline require_admin
    # (mount HTTP) + hook LiveAuth (juga reconnect websocket).
    ash_authentication_live_session :admin_live,
      on_mount: [{StellarWeb.LiveAuth, :require_admin}] do
      live "/users", UserLive, :index
      live "/users/new", UserLive, :new
      live "/users/:id/edit", UserLive, :edit

      live "/skills", SkillLive, :index
      live "/skills/new", SkillLive, :new
      live "/skills/:id/edit", SkillLive, :edit

      live "/roles", RoleLive, :index
      live "/roles/new", RoleLive, :new
      live "/roles/:id/edit", RoleLive, :edit

      live "/permissions", PermissionLive, :index
      live "/permissions/new", PermissionLive, :new
      live "/permissions/:id/edit", PermissionLive, :edit

      live "/industries", IndustryLive, :index
      live "/industries/new", IndustryLive, :new
      live "/industries/:id/edit", IndustryLive, :edit

      live "/sections", SectionLive, :index
      live "/sections/new", SectionLive, :new
      live "/sections/:id/edit", SectionLive, :edit
    end
  end

  # Surface per-org (RBAC): akses via permission, bukan superuser-only.
  # Superuser tetap lolos (permissions = :all). Scoping data per-org di controller.
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_orgs_read]

    # LiveView (pola pilot Skills + hook per-org).
    ash_authentication_live_session :orgs_live,
      on_mount: [
        {StellarWeb.LiveAuth, :assign_org},
        {StellarWeb.LiveAuth, {:require, "organizations:read"}}
      ] do
      live "/organizations", OrganizationLive, :index
      live "/organizations/new", OrganizationLive, :new
      live "/organizations/:id/edit", OrganizationLive, :edit
    end
  end

  # Bank dokumen (RBAC): butuh documents:manage. Scoping data per-org di controller.
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_documents_manage]

    # LiveView (pola pilot Skills + hook per-org).
    ash_authentication_live_session :documents_live,
      on_mount: [
        {StellarWeb.LiveAuth, :assign_org},
        {StellarWeb.LiveAuth, {:require, "documents:manage"}}
      ] do
      live "/documents", DocumentLive, :index
      live "/documents/new", DocumentLive, :new
    end
  end

  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_members_read]

    # LiveView per-org (pola pilot Skills + hook :assign_org): scoping org aktif,
    # members:read lihat, members:manage kelola — gate juga di dalam LiveView.
    ash_authentication_live_session :members_live,
      on_mount: [
        {StellarWeb.LiveAuth, :assign_org},
        {StellarWeb.LiveAuth, {:require, ["members:read", "members:manage"]}}
      ] do
      live "/memberships", MembershipLive, :index
      live "/memberships/new", MembershipLive, :new
      live "/memberships/:id/edit", MembershipLive, :edit

      live "/membership-roles", MembershipRoleLive, :index
      live "/membership-roles/new", MembershipRoleLive, :new
    end
  end

  # Course admin (per-tenant). Gate courses:read (route); courses:manage per-aksi
  # di LiveView. Scoping data per-org di LiveView.
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_courses_read]

    # LiveView (pola pilot Skills + hook per-org). Edit = full-page workspace
    # (panel Materi), bukan modal — beda dari menu lain.
    ash_authentication_live_session :courses_live,
      on_mount: [
        {StellarWeb.LiveAuth, :assign_org},
        {StellarWeb.LiveAuth,
         {:require,
          ["courses:read", "courses:create", "courses:update", "courses:delete", "courses:manage"]}}
      ] do
      live "/courses", CourseLive, :index
      live "/courses/new", CourseLive, :new
      live "/courses/:id/edit", CourseLive, :edit
    end
  end

  # Class admin (per-tenant): gate granular classes:*/enrollments:* (di controller).
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_classes_read]

    # LiveView (pola pilot Skills + hook per-org): panel peserta & jadwal jadi
    # event LiveView — route enrollment terpisah tak diperlukan lagi.
    ash_authentication_live_session :classes_live,
      on_mount: [
        {StellarWeb.LiveAuth, :assign_org},
        {StellarWeb.LiveAuth,
         {:require,
          [
            "classes:read",
            "classes:create",
            "classes:update",
            "classes:delete",
            "classes:manage",
            "enrollments:read",
            "enrollments:create",
            "enrollments:update",
            "enrollments:delete",
            "enrollments:manage"
          ]}}
      ] do
      live "/classes", ClassLive, :index
      live "/classes/new", ClassLive, :new
      live "/classes/:id/edit", ClassLive, :edit
    end
  end

  # Menu Teachers (read-only: list + detail). Gate teachers:*.
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_teachers_read]

    # LiveView (pola pilot Skills + hook per-org). Read-only: index + detail.
    ash_authentication_live_session :teachers_live,
      on_mount: [
        {StellarWeb.LiveAuth, :assign_org},
        {StellarWeb.LiveAuth, {:require, ["teachers:read", "teachers:manage"]}}
      ] do
      live "/teachers", TeacherLive, :index
      live "/teachers/:id", TeacherLive, :show
    end
  end

  # Enrollment admin (mandiri). Gate granular enrollments:* di dalam LiveView.
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_enrollments_read]

    ash_authentication_live_session :enrollments_live,
      on_mount: [
        {StellarWeb.LiveAuth, :assign_org},
        {StellarWeb.LiveAuth,
         {:require,
          [
            "enrollments:read",
            "enrollments:create",
            "enrollments:update",
            "enrollments:delete",
            "enrollments:manage"
          ]}}
      ] do
      live "/enrollments", EnrollmentLive, :index
      live "/enrollments/new", EnrollmentLive, :new
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stellar_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StellarWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
