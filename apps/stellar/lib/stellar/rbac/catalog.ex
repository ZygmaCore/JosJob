defmodule Stellar.Rbac.Catalog do
  @moduledoc """
  Katalog **permission & role sistem** — satu sumber kebenaran.

  Sebelumnya daftar ini hidup sebagai module-attribute privat di
  `Stellar.Release`. Diangkat ke sini agar DUA pemakai bisa berbagi definisi yang
  sama tanpa risiko drift:

    1. `Stellar.Release.seed/0` — seed permissions + role global saat deploy.
    2. `Stellar.Rbac.Provisioning` — jamin role sistem (mis. `"teacher"`) ada di
       sebuah organisasi saat undangan diterima (org dipilih superuser per undangan).

  Konvensi permission granular: `:read` / `:create` / `:update` / `:delete`, plus
  `:manage` sebagai SUPERSET.
  """

  # {key, category, description}. Idempoten via upsert key saat di-seed.
  @permissions [
    # Dashboard
    {"dashboard:view", "dashboard", "View dashboard"},

    # Users (placeholder — halaman users superuser-only)
    {"users:read", "users", "View users"},
    {"users:manage", "users", "Manage users"},

    # Organisasi & keanggotaan
    {"organizations:read", "org", "View organizations"},
    {"organizations:manage", "org", "Manage organizations"},
    {"members:read", "org", "View organization members"},
    {"members:manage", "org", "Manage organization members"},
    {"roles:read", "org", "View roles (placeholder)"},
    {"roles:manage", "org", "Manage roles (placeholder)"},

    # Learning — Course
    {"courses:read", "learning", "View courses"},
    {"courses:create", "learning", "Add courses"},
    {"courses:update", "learning", "Edit courses"},
    {"courses:delete", "learning", "Delete courses"},
    {"courses:manage", "learning", "Manage courses (all actions)"},

    # Learning — Class
    {"classes:read", "learning", "View classes"},
    {"classes:create", "learning", "Add classes"},
    {"classes:update", "learning", "Edit classes"},
    {"classes:delete", "learning", "Delete classes"},
    {"classes:manage", "learning", "Manage classes (all actions)"},

    # Learning — Enrollment (peserta kelas)
    {"enrollments:read", "learning", "View class participants"},
    {"enrollments:create", "learning", "Enroll students into a class"},
    {"enrollments:update", "learning", "Change participant status"},
    {"enrollments:delete", "learning", "Remove participants from a class"},
    {"enrollments:manage", "learning", "Manage class participants (all actions)"},

    # Learning — Teacher (menu Teachers: list/detail)
    {"teachers:read", "learning", "View teachers & the classes they teach"},
    {"teachers:manage", "learning", "Manage teachers (placeholder)"},

    # Learning — Section/jurusan (placeholder — superuser-only)
    {"sections:manage", "learning", "Manage sections/majors (placeholder)"},

    # Dokumen
    {"documents:read", "document", "View document bank (placeholder)"},
    {"documents:manage", "document", "Manage document bank"},

    # Master data (placeholder — superuser-only)
    {"industries:manage", "master", "Manage industries (placeholder)"},
    {"skills:manage", "master", "Manage skills (placeholder)"},
    {"countries:manage", "master", "Manage countries (placeholder)"},
    {"professions:manage", "master", "Manage professions (placeholder)"},

    # Jobs — organization-scoped listing access and employer management.
    {"jobs:read", "jobs", "View job listings"},
    {"jobs:post", "jobs", "Post job listings"},
    {"jobs:manage", "jobs", "Manage job listings"},
    {"jobs:apply", "jobs", "Apply to job listings"}
  ]

  # Role global (sistem) + izinnya. Lihat PRD docs/enhancement/users_and_roles.md §5.
  # `teacher` mengunggah/mengelola dokumen (video/pdf/doc) → diberi izin document.
  @roles %{
    "employer" =>
      {"Employer", ~w(dashboard:view organizations:read members:manage jobs:post jobs:manage)},
    "coordinator" =>
      {"Coordinator",
       ~w(dashboard:view users:read members:manage courses:manage classes:manage teachers:read enrollments:manage documents:manage)},
    "teacher" =>
      {"Teacher",
       ~w(dashboard:view courses:read courses:manage classes:manage teachers:read enrollments:manage documents:read documents:manage)},
    "worker" => {"Worker", ~w(dashboard:view courses:read jobs:read jobs:apply)},
    "graduate" => {"Graduate", ~w(dashboard:view jobs:read jobs:apply)}
  }

  @doc "Daftar permission `{key, category, description}`."
  def permissions, do: @permissions

  @doc "Map role sistem: `key => {name, [permission_key]}`."
  def roles, do: @roles

  @doc "Definisi satu role sistem `{name, [permission_key]}`, atau nil bila tak ada."
  def role(key) when is_binary(key), do: Map.get(@roles, key)

  @doc "Metadata satu permission `{key, category, description}`, atau nil."
  def permission(key) when is_binary(key),
    do: Enum.find(@permissions, fn {k, _c, _d} -> k == key end)
end
