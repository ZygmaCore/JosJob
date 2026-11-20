defmodule JosjobLrn.DemoSeed do
  @moduledoc """
  Demo seed: 1000 baris data sintetis di SEMUA tabel yang bisa di-seed lewat Ash
  (22 tabel, termasuk `jobs` — tabel lowongan yang baru ada sejak
  `20261111151922_create_jobs`).

  Cara pakai (dari root repo):

      mix run apps/josjob/priv/repo/demo_seeds.exs

  Atau dari `iex -S mix`:

      JosjobLrn.DemoSeed.seed()

  Prinsipnya — simple, reusable, no rocket science:

    * SATU modul, SATU fungsi utama (`seed/0`), tanpa dependency baru.
    * Deterministik: `:rand` di-seed tetap, jadi tiap run menghasilkan data yang
      sama (email `demo001@josjob.test`, dst.). Password semua user demo:
      `"demo1234"`.
    * Idempotent: tiap baris dicari dulu by natural key (email, nama, judul,
      atau upsert identity); run kedua tidak menduplikasi.
    * Total SELALU 1000: distribusi ada di `@counts`, dan `seed/0` raise bila
      jumlah baris yang di-ensure bukan 1000 (menangkap perubahan skema).
    * TIDAK dipanggil dari `Josjob.Release.seed/0` — data demo tidak boleh
      ikut ter-seed otomatis tiap deploy. Jalankan script ini hanya di dev/demo.

  Yang TIDAK masuk hitungan 1000 (sengaja, bukan kelupaan):

    * Master data (countries, industries, professions, skills) — sudah di-seed
      `Josjob.Release.seed/0` dari modul `*Data`; script ini HANYA memakainya
      sebagai lookup. `seed/0` memanggil `Josjob.Release.seed()` dulu supaya
      base data selalu ada.
    * RBAC (permissions, roles, role_permissions) — di-provision per org oleh
      `Josjob.Rbac.Provisioning`; script ini memanggilnya untuk tiap org demo
      (infra, bukan data demo).
    * `tokens`, `user_identities` — internal auth, jangan pernah di-seed.
    * `lectures`, `transcripts`, `video_checkpoints` — tabel ada di migrasi tapi
      TIDAK punya Ash resource, jadi tidak ada jalur seed lewat Ash.
    * `payment_webhook_events` — log webhook Stripe; tidak bermakna sebagai
      data demo.

  Riwayat singkat: script ini pertama ditulis saat repo masih bernama lama,
  lalu ditulis ulang setelah `git pull` (12 Nov 2026) karena remote `dev`
  sudah rebrand total ke Josjob (path `apps/josjob*`, namespace `Josjob*`)
  plus tabel `jobs` baru. Versi lama (commit lokal yang tidak pernah di-push)
  dibuang — jangan dicari lagi.

  Catatan verifikasi: script ini ditulis dari definisi resource di repo
  (dicek satu per satu: atribut, action `accept`, dan identity — semua file
  resource yang dipakai terverifikasi rename-only dari versi lama, kecuali
  `JosjobJob.Job` yang baru). BELUM sempat dieksekusi di VM ini (tidak ada
  Elixir/Docker di sini) — jalankan sekali di mesin dev (`mix ecto.reset`
  dulu bila DB sudah berisi data demo lama, atau biarkan idempotent-nya
  bekerja) dan laporkan error bila ada.
  """
  require Ash.Query

  alias Josjob.Accounts.{Profile, User, UserDetail}
  alias Josjob.Invitations.Invitation
  alias Josjob.Orgs.{Industry, Membership, Organization, Skill}
  alias Josjob.Payments.{Customer, Payment, Price, Product, Subscription}
  alias Josjob.Rbac.{Catalog, MembershipRole, Provisioning, Role}
  alias JosjobDoc.Documents.{Document, DocumentAccessGrant}
  alias JosjobJob.Job

  alias JosjobLrn.Learning.{
    Class,
    Course,
    CourseIndustry,
    CourseOrganization,
    Enrollment,
    Section,
    SectionOrganization
  }

  @password "demo1234"
  @email_domain "josjob.test"
  @rand_seed {42, 7, 2026}

  # Distribusi 1000 baris. Ubah di sini (dan hanya di sini) bila perlu;
  # `seed/0` akan raise bila totalnya bukan 1000.
  @counts [
    organizations: 10,
    users: 160,
    memberships: 90,
    membership_roles: 90,
    profiles: 50,
    user_details: 40,
    sections: 6,
    courses: 42,
    classes: 84,
    enrollments: 120,
    jobs: 60,
    documents: 36,
    document_access_grants: 18,
    invitations: 24,
    payment_products: 6,
    payment_prices: 12,
    payment_customers: 18,
    payment_subscriptions: 10,
    payments: 10,
    section_organizations: 12,
    course_organizations: 42,
    course_industries: 60
  ]

  @doc "Distribusi default (jumlah baris per tabel)."
  def counts, do: @counts

  @doc "Total baris yang di-seed (harus 1000)."
  def total, do: Enum.sum(Keyword.values(@counts))

  @doc """
  Seed 1000 baris data demo. Opts:

    * `:counts` — keyword override, mis. `seed(counts: [users: 50])`.
    * `:rand_seed` — tuple seed `:rand`, default `{42, 7, 2026}`.

  Mengembalikan map `%{tabel => jumlah}` bila sukses; raise bila total != 1000.
  """
  def seed(opts \\ []) do
    counts = Keyword.merge(@counts, Keyword.get(opts, :counts, []))
    :rand.seed(:exsss, Keyword.get(opts, :rand_seed, @rand_seed))
    {:ok, _} = Application.ensure_all_started(:josjob_lrn)

    # Base data dulu (superuser, org Atveti, RBAC, master data, katalog sampel).
    # Idempotent; wajib ada sebelum demo seed (dipakai sebagai owner/lookup).
    superuser = Josjob.Release.seed()

    users = seed_users(counts[:users])
    orgs = seed_organizations(counts[:organizations], superuser.id)
    provision_org_roles(orgs)
    memberships = seed_memberships(counts[:memberships], users, orgs)
    roles_count = seed_membership_roles(counts[:membership_roles], memberships)
    profiles_count = seed_profiles(counts[:profiles], users)
    details_count = seed_user_details(counts[:user_details], users)
    sections = seed_sections(counts[:sections])
    {courses, course_orgs} = seed_courses(counts[:courses], sections, orgs)
    classes = seed_classes(counts[:classes], courses, course_orgs, users)
    enrollments_count = seed_enrollments(counts[:enrollments], classes, users)
    jobs_count = seed_jobs(counts[:jobs], orgs, users)
    documents = seed_documents(counts[:documents], courses, course_orgs, users)
    grants_count = seed_grants(counts[:document_access_grants], documents, users, superuser.id)
    invitations_count = seed_invitations(counts[:invitations], orgs, superuser.id)
    products = seed_products(counts[:payment_products])
    prices = seed_prices(counts[:payment_prices], products)
    customers = seed_customers(counts[:payment_customers], users)
    subscriptions_count = seed_subscriptions(counts[:payment_subscriptions], customers, prices)
    payments_count = seed_payments(counts[:payments], customers, prices)
    section_orgs_count = seed_section_orgs(counts[:section_organizations], sections, orgs)
    course_orgs_count = seed_course_orgs(counts[:course_organizations], courses, course_orgs)
    course_industries_count = seed_course_industries(counts[:course_industries], courses)

    result = %{
      organizations: length(orgs),
      users: length(users),
      memberships: length(memberships),
      membership_roles: roles_count,
      profiles: profiles_count,
      user_details: details_count,
      sections: length(sections),
      courses: length(courses),
      classes: length(classes),
      enrollments: enrollments_count,
      jobs: jobs_count,
      documents: length(documents),
      document_access_grants: grants_count,
      invitations: invitations_count,
      payment_products: length(products),
      payment_prices: length(prices),
      payment_customers: length(customers),
      payment_subscriptions: subscriptions_count,
      payments: payments_count,
      section_organizations: section_orgs_count,
      course_organizations: course_orgs_count,
      course_industries: course_industries_count
    }

    total = Enum.sum(Map.values(result))

    if total != 1000 do
      raise "JosjobLrn.DemoSeed: total #{total}, harus 1000. Cek @counts."
    end

    IO.puts("""
    Demo seed selesai (total #{total} baris).
    #{Enum.map_join(result, "\n  ", fn {k, v} -> "#{k}: #{v}" end)}
      Login demo: email demo001@#{@email_domain} .. demo#{counts[:users]}@#{@email_domain}, password #{@password}
    """)

    result
  end

  # ---- helpers -----------------------------------------------------------

  # Baris pertama yang cocok (atau nil). Dipakai get-or-create; `read_one!`
  # akan RAISE bila ada duplikat, jadi jangan dipakai di sini.
  defp one(query), do: query |> Ash.read!(authorize?: false) |> List.first()

  defp create!(resource, action, attrs, opts \\ []) do
    resource
    |> Ash.Changeset.for_create(action, attrs)
    |> Ash.create!(Keyword.merge([authorize?: false], opts))
  end

  defp upsert!(resource, action, attrs, identity) do
    create!(resource, action, attrs, upsert?: true, upsert_identity: identity)
  end

  defp pick(list), do: Enum.random(list)
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(3, "0")

  # ---- data nama (Indonesia) ----------------------------------------------

  @first_names ~w(Ayu Budi Citra Dewi Eko Fitri Gilang Hana Irfan Joko Kirana Lukman
    Maya Nanda Putri Rizky Sari Tono Utami Wahyu Yuni Agus Bella Dian Fajar Intan
    Kusuma Lestari Made Nina Raka Sinta Tegar Wulan Yoga Zahra Andi Ratna Dedi Lina)

  @last_names ~w(Santoso Wijaya Saputra Pratama Kusuma Hidayat Nugroho Rahmawati
    Setiawan Anggraini Puspita Gunawan Maharani Firmansyah Utama Lestari Pangestu
    Wulandari Hakim Nugraha Siregar Halim Kurniawan Sari Maulana Febrianti
    Ramadhan Permata Hartono Sulistyo)

  defp full_name do
    pick(@first_names) <> " " <> pick(@last_names)
  end

  @org_names [
    "PT Maju Bersama",
    "Yayasan Cendekia Nusantara",
    "PT Digital Kreasi Bangsa",
    "Kampus Vokasi Merdeka",
    "PT Solusi Talenta Indonesia",
    "LPK Bina Karier",
    "PT Nusantara Hospitality Group",
    "Yayasan Pendidikan Harapan Bangsa",
    "PT Konstruksi Andalan Jaya",
    "Studio Kreatif Arunika"
  ]

  @sections [
    {"Teknologi Informasi", "Kursus seputar pemrograman, data, dan infrastruktur IT."},
    {"Bisnis & Manajemen", "Kursus seputar manajemen, pemasaran, dan kewirausahaan."},
    {"Kesehatan", "Kursus seputar layanan kesehatan dan perawatan."},
    {"Hospitality & Pariwisata", "Kursus seputar layanan tamu, boga, dan wisata."},
    {"Konstruksi", "Kursus seputar keselamatan dan keterampilan konstruksi."},
    {"Kreatif & Desain", "Kursus seputar desain, konten, dan produksi kreatif."}
  ]

  # 7 topik per section = 42 course. Judul harus unik per section.
  @course_topics %{
    "Teknologi Informasi" => [
      "Dasar Pemrograman Python",
      "Pengembangan Web dengan Elixir",
      "Basis Data & SQL Praktis",
      "Jaringan Komputer untuk Pemula",
      "Keamanan Siber Dasar",
      "Analisis Data dengan Spreadsheet",
      "Pengenalan Kecerdasan Buatan"
    ],
    "Bisnis & Manajemen" => [
      "Dasar Manajemen Proyek",
      "Pemasaran Digital untuk UMKM",
      "Akuntansi Keuangan Dasar",
      "Kewirausahaan: Dari Ide ke Pasar",
      "Manajemen SDM untuk Pemula",
      "Negosiasi & Komunikasi Bisnis",
      "Perencanaan Bisnis Sederhana"
    ],
    "Kesehatan" => [
      "Pertolongan Pertama (P3K)",
      "Dasar Keperawatan Komunitas",
      "Gizi Seimbang & Pola Hidup Sehat",
      "Kesehatan Mental di Tempat Kerja",
      "Pencegahan & Pengendalian Infeksi",
      "Perawatan Lansia di Rumah",
      "Farmasi Dasar untuk Asisten Apoteker"
    ],
    "Hospitality & Pariwisata" => [
      "Layanan Tamu & Front Office",
      "Tata Boga Dasar",
      "Housekeeping Hotel",
      "Pemandu Wisata Lokal",
      "Manajemen Acara & MICE",
      "Barista & Layanan Minuman",
      "Etika Layanan Pelanggan"
    ],
    "Konstruksi" => [
      "Keselamatan Kerja (K3) Dasar",
      "Membaca Gambar Teknik",
      "Tukang Bangunan: Fondasi & Dinding",
      "Instalasi Listrik Rumah Tangga",
      "Pengelasan Dasar",
      "Manajemen Proyek Konstruksi Kecil",
      "Survey & Pengukuran Lahan"
    ],
    "Kreatif & Desain" => [
      "Desain Grafis dengan Canva",
      "Fotografi Produk untuk UMKM",
      "Menulis Konten & Copywriting",
      "Video Editing untuk Pemula",
      "Ilustrasi Digital Dasar",
      "Branding untuk Bisnis Kecil",
      "Musik & Produksi Audio Rumahan"
    ]
  }

  @paid_prices [4900, 9900, 19_900]
  @role_keys ["graduate", "worker", "teacher", "employer", "coordinator"]
  @goals ["Dapat kerja pertama", "Naik jabatan", "Pindah industri", "Belajar skill baru"]
  @locations ["Jakarta", "Bandung", "Surabaya", "Yogyakarta", "Remote"]
  @hobbies ["Membaca", "Olahraga", "Musik", "Memasak", "Fotografi", "Gaming"]

  # ---- users ---------------------------------------------------------------

  defp seed_users(count) do
    for i <- 1..count do
      email = "demo#{pad(i)}@#{@email_domain}"
      get_or_create_user(email)
    end
  end

  defp get_or_create_user(email) do
    User |> Ash.Query.filter(email == ^email) |> one() ||
      create!(User, :register_with_email, %{
        email: email,
        full_name: full_name(),
        password: @password,
        account_type: :personal
      })
  end

  # ---- organizations + RBAC -------------------------------------------------

  defp seed_organizations(count, owner_id) do
    industries = Industry |> Ash.read!(authorize?: false)

    @org_names
    |> Enum.take(count)
    |> Enum.map(fn name ->
      get_or_create_org(name, owner_id, pick(industries).id)
    end)
  end

  defp get_or_create_org(name, owner_id, industry_id) do
    Organization |> Ash.Query.filter(name == ^name) |> one() ||
      create!(Organization, :create, %{
        name: name,
        user_id: owner_id,
        industry_id: industry_id,
        additional_info: "Org demo (sintetis) — JosjobLrn.DemoSeed."
      })
  end

  # Role sistem per org demo (infra; tidak masuk hitungan 1000).
  defp provision_org_roles(orgs) do
    for org <- orgs, key <- Map.keys(Catalog.roles()) do
      Provisioning.ensure_org_role!(org.id, key)
    end

    :ok
  end

  defp seed_memberships(count, users, orgs) do
    users
    |> Enum.take(count)
    |> Enum.with_index()
    |> Enum.map(fn {user, i} ->
      org = Enum.at(orgs, rem(i, length(orgs)))

      upsert!(
        Membership,
        :create,
        %{user_id: user.id, organization_id: org.id, status: pick_status()},
        :unique_user_org
      )
    end)
  end

  defp pick_status do
    case :rand.uniform(10) do
      n when n <= 8 -> :active
      9 -> :invited
      _ -> :suspended
    end
  end

  defp seed_membership_roles(count, memberships) do
    memberships
    |> Enum.take(count)
    |> Enum.map(fn membership ->
      role_key = pick(@role_keys)

      role =
        Role
        |> Ash.Query.filter(organization_id == ^membership.organization_id and key == ^role_key)
        |> one()

      upsert!(
        MembershipRole,
        :create,
        %{membership_id: membership.id, role_id: role.id},
        :unique_membership_role
      )
    end)
    |> length()
  end

  # ---- profile + user_detail -------------------------------------------------

  defp seed_profiles(count, users) do
    skills = Skill |> Ash.read!(authorize?: false) |> Enum.map(& &1.name)

    users
    |> Enum.take(count)
    |> Enum.map(fn user ->
      create!(Profile, :upsert_answers, %{
        user_id: user.id,
        answers: %{
          "goal" => pick(@goals),
          "location_preference" => pick(@locations),
          "skills" => Enum.take_random(skills, 3),
          "experience_years" => :rand.uniform(6) - 1
        },
        answers_updated_at: DateTime.utc_now()
      })
    end)
    |> length()
  end

  defp seed_user_details(count, users) do
    skills = Skill |> Ash.read!(authorize?: false)
    industries = Industry |> Ash.read!(authorize?: false)

    users
    |> Enum.drop(50)
    |> Enum.take(count)
    |> Enum.map(fn user ->
      chosen_skills = Enum.take_random(skills, 3)

      create!(UserDetail, :upsert_details, %{
        user_id: user.id,
        resume: %{
          skills: Enum.map(chosen_skills, & &1.name),
          skill_ids: Enum.map(chosen_skills, & &1.id),
          employments: [
            %{
              name: pick(@org_names),
              position: "Staff",
              industry: pick(industries).name,
              from: %{month: 1, year: 2022},
              to: %{month: 12, year: 2023}
            }
          ]
        },
        education: %{
          formal: [
            %{
              degree: "S1",
              major: pick(["Informatika", "Manajemen", "Akuntansi", "Keperawatan"]),
              name:
                pick([
                  "Universitas Gadjah Mada",
                  "Institut Teknologi Bandung",
                  "Universitas Indonesia"
                ]),
              type: "university",
              from: %{month: 8, year: 2019},
              to: %{month: 7, year: 2023}
            }
          ],
          achievements: []
        },
        interest: %{
          hobbies: Enum.take_random(@hobbies, 2),
          industry_ids: industries |> Enum.take_random(2) |> Enum.map(& &1.id)
        }
      })
    end)
    |> length()
  end

  # ---- learning: sections, courses, classes, enrollments --------------------

  defp seed_sections(count) do
    @sections
    |> Enum.take(count)
    |> Enum.map(fn {name, description} ->
      Section |> Ash.Query.filter(name == ^name) |> one() ||
        create!(Section, :create, %{name: name, description: description, is_active: true})
    end)
  end

  # Mengembalikan {courses, course_orgs}: course_orgs[i] = org untuk course ke-i,
  # dipakai lagi oleh classes + course_organizations supaya konsisten.
  defp seed_courses(count, sections, orgs) do
    wanted =
      for section <- sections,
          topic <- Map.fetch!(@course_topics, section.name),
          do: {section, topic}

    courses =
      wanted
      |> Enum.take(count)
      |> Enum.with_index()
      |> Enum.map(fn {{section, topic}, i} ->
        get_or_create_course(topic, section, i)
      end)

    course_orgs =
      Enum.map(Enum.with_index(courses), fn {_c, i} -> Enum.at(orgs, rem(i, length(orgs))) end)

    {courses, course_orgs}
  end

  defp get_or_create_course(title, section, i) do
    Course |> Ash.Query.filter(title == ^title and section_id == ^section.id) |> one() ||
      create!(Course, :create, %{
        title: title,
        description: "Kursus demo: #{title}. Data sintetis (JosjobLrn.DemoSeed).",
        is_active: true,
        is_public: rem(i, 2) == 0,
        price_cents: course_price(i),
        currency: "usd",
        section_id: section.id
      })
  end

  defp course_price(i) do
    if rem(i, 3) == 0, do: nil, else: Enum.at(@paid_prices, rem(i, length(@paid_prices)))
  end

  defp seed_classes(count, courses, course_orgs, users) do
    wanted =
      for {course, ci} <- Enum.with_index(courses),
          n <- [1, 2],
          do: {course, ci, n}

    wanted
    |> Enum.take(count)
    |> Enum.map(fn {course, ci, n} ->
      title = "#{course.title} — Kelas #{n}"
      org = Enum.at(course_orgs, ci)
      instructor = Enum.at(users, rem(ci * 2 + n, length(users)))

      Class |> Ash.Query.filter(title == ^title and course_id == ^course.id) |> one() ||
        create!(Class, :create, %{
          title: title,
          schedule: [
            %{"date" => "2026-11-20", "start" => "09:00", "end" => "11:00"},
            %{"date" => "2026-11-27", "start" => "09:00", "end" => "11:00"}
          ],
          capacity: 50,
          course_id: course.id,
          organization_id: org.id,
          instructor_id: instructor.id
        })
    end)
  end

  defp seed_enrollments(count, classes, users) do
    # Pasangan (class, student) unik: periode lcm(84, 160) = 1680 > 120.
    for i <- 0..(count - 1) do
      class = Enum.at(classes, rem(i, length(classes)))
      student = Enum.at(users, rem(i * 7, length(users)))
      status = if rem(i, 7) == 0, do: :completed, else: :active

      upsert!(
        Enrollment,
        :create,
        %{class_id: class.id, student_id: student.id, status: status},
        :unique_class_student
      )
    end
    |> length()
  end

  # ---- jobs --------------------------------------------------------------------

  # 20 judul dasar x 3 level = 60 judul unik (lcm(3, 20) = 60). Get-or-create
  # by (title, organization_id); Job tidak punya unique identity.
  @job_titles [
    "Backend Developer",
    "Frontend Developer",
    "Data Analyst",
    "UI/UX Designer",
    "Digital Marketing Staff",
    "Customer Service",
    "Akuntan Junior",
    "Perawat",
    "Chef de Partie",
    "Teknisi Listrik",
    "Admin Gudang",
    "Sales Executive",
    "Content Writer",
    "QA Engineer",
    "Barista",
    "Housekeeping Staff",
    "Project Coordinator",
    "Guru Les Privat",
    "Desainer Grafis",
    "Operator Produksi"
  ]

  @job_levels ["Junior", "Mid-Level", "Senior"]
  @job_locations [
    "Jakarta",
    "Bandung",
    "Surabaya",
    "Yogyakarta",
    "Medan",
    "Makassar",
    "Semarang",
    "Remote"
  ]
  @job_types ["full-time", "part-time", "internship", "contract", "freelance"]
  @job_modes ["remote", "hybrid", "onsite"]
  @salary_mins [4_000_000, 5_000_000, 6_000_000, 8_000_000, 10_000_000, 12_000_000]
  @salary_bumps [1_000_000, 2_000_000, 3_000_000, 5_000_000]
  @job_highlights [
    "Gaji kompetitif",
    "BPJS Kesehatan & Ketenagakerjaan",
    "Kerja remote/hybrid",
    "Jenjang karier jelas",
    "Pelatihan & sertifikasi",
    "Tunjangan makan & transport"
  ]

  defp seed_jobs(count, orgs, users) do
    skills = Skill |> Ash.read!(authorize?: false) |> Enum.map(& &1.name)
    industries = Industry |> Ash.read!(authorize?: false)

    for i <- 0..(count - 1) do
      org = Enum.at(orgs, rem(i, length(orgs)))
      title = "#{Enum.at(@job_levels, rem(i, 3))} #{Enum.at(@job_titles, rem(i, 20))}"
      status = job_status(i)

      get_or_create_job(%{
        title: title,
        description:
          "Lowongan demo: #{title} di #{org.name}. Data sintetis (JosjobLrn.DemoSeed).",
        location: pick(@job_locations),
        industry: pick(industries).name,
        employment_type: Enum.at(@job_types, rem(i, length(@job_types))),
        work_mode: Enum.at(@job_modes, rem(i, length(@job_modes))),
        requirements: Enum.take_random(skills, 3),
        highlights: Enum.take_random(@job_highlights, 2),
        salary_min: job_salary_min(i),
        salary_max: job_salary_max(i),
        currency: "IDR",
        status: status,
        organization_id: org.id,
        created_by: Enum.at(users, rem(i, length(users))).id,
        synthetic: true,
        posted_at: job_posted_at(i, status)
      })
    end
    |> length()
  end

  # 7 dari 10 aktif, 2 draft, 1 expired.
  defp job_status(i) do
    case rem(i, 10) do
      n when n in [7, 8] -> "draft"
      9 -> "expired"
      _ -> "active"
    end
  end

  # 1 dari 6 lowongan tanpa info gaji (min & max nil).
  defp job_salary_min(i) do
    if rem(i, 6) == 0, do: nil, else: Enum.at(@salary_mins, rem(i, length(@salary_mins)))
  end

  defp job_salary_max(i) do
    case job_salary_min(i) do
      nil -> nil
      min -> min + Enum.at(@salary_bumps, rem(i, length(@salary_bumps)))
    end
  end

  defp job_posted_at(i, "active"),
    do: DateTime.add(DateTime.utc_now(), -rem(i, 30) * 86_400, :second)

  defp job_posted_at(_i, "expired"), do: DateTime.add(DateTime.utc_now(), -60 * 86_400, :second)
  defp job_posted_at(_i, _status), do: nil

  defp get_or_create_job(attrs) do
    %{title: title, organization_id: org_id} = attrs

    Job |> Ash.Query.filter(title == ^title and organization_id == ^org_id) |> one() ||
      Job
      |> Ash.Changeset.for_create(
        :create,
        Map.drop(attrs, [:organization_id, :created_by, :synthetic, :posted_at])
      )
      # Pola yang sama dipakai JosjobJob.Listings.create/3: organization_id,
      # created_by, synthetic, dan posted_at TIDAK ada di default_accept,
      # jadi di-set paksa setelah for_create.
      |> Ash.Changeset.force_change_attribute(:organization_id, attrs.organization_id)
      |> Ash.Changeset.force_change_attribute(:created_by, attrs.created_by)
      |> Ash.Changeset.force_change_attribute(:synthetic, true)
      |> maybe_stamp_posted_at(attrs.posted_at)
      |> Ash.create!(authorize?: false)
  end

  defp maybe_stamp_posted_at(changeset, nil), do: changeset

  defp maybe_stamp_posted_at(changeset, posted_at),
    do: Ash.Changeset.force_change_attribute(changeset, :posted_at, posted_at)

  # ---- documents + grants -----------------------------------------------------

  defp seed_documents(count, courses, course_orgs, users) do
    course_docs = div(count * 2, 3)
    user_docs = count - course_docs

    docs =
      for i <- 1..course_docs do
        ci = rem(i - 1, length(courses))
        course = Enum.at(courses, ci)
        org = Enum.at(course_orgs, ci)

        get_or_create_document(
          "Materi: #{course.title} — Modul #{rem(i - 1, 3) + 1}",
          "https://demo.#{@email_domain}/materi/#{course.id}/modul-#{rem(i - 1, 3) + 1}.pdf",
          course.id,
          Enum.at(users, rem(i, length(users))).id,
          org.id
        )
      end

    docs ++
      for i <- 1..user_docs do
        user = Enum.at(users, rem(i * 3, length(users)))

        get_or_create_document(
          "Dokumen #{user.id |> to_string() |> String.slice(0, 8)} — CV",
          "https://demo.#{@email_domain}/cv/#{user.id}.pdf",
          nil,
          user.id,
          Enum.at(course_orgs, rem(i, length(course_orgs))).id
        )
      end
  end

  defp get_or_create_document(title, url, course_id, user_id, org_id) do
    Document |> Ash.Query.filter(title == ^title and user_id == ^user_id) |> one() ||
      create!(Document, :create, %{
        title: title,
        url: url,
        mime_type: "application/pdf",
        description: "Dokumen demo (sintetis).",
        course_id: course_id,
        user_id: user_id,
        organization_id: org_id
      })
  end

  defp seed_grants(count, documents, users, granted_by_id) do
    for i <- 0..(count - 1) do
      doc = Enum.at(documents, rem(i, length(documents)))
      user = Enum.at(users, rem(i * 5, length(users)))

      upsert!(
        DocumentAccessGrant,
        :upsert,
        %{
          document_id: doc.id,
          user_id: user.id,
          allow: true,
          granted_by_id: granted_by_id,
          valid_from: DateTime.utc_now(),
          valid_until: DateTime.add(DateTime.utc_now(), 90 * 86_400, :second)
        },
        :unique_document_user
      )
    end
    |> length()
  end

  # ---- invitations ------------------------------------------------------------

  defp seed_invitations(count, orgs, invited_by_id) do
    for i <- 1..count do
      email = "invite#{pad(i)}@#{@email_domain}"
      org = Enum.at(orgs, rem(i - 1, length(orgs)))

      Invitation |> Ash.Query.filter(email == ^email) |> one() ||
        create!(Invitation, :create, %{
          email: email,
          role_key: Enum.at(@role_keys, rem(i - 1, length(@role_keys))),
          organization_id: org.id,
          invited_by_id: invited_by_id
        })
    end
    |> length()
  end

  # ---- payments (mirror Stripe — TIDAK ada panggilan API) ----------------------

  defp seed_products(count) do
    names = [
      "Paket Belajar Starter",
      "Paket Belajar Pro",
      "Paket Karier Plus",
      "Paket Kursus Tim",
      "Paket Sertifikasi",
      "Paket Belajar Tahunan"
    ]

    names
    |> Enum.take(count)
    |> Enum.with_index(1)
    |> Enum.map(fn {name, i} ->
      upsert!(
        Product,
        :upsert,
        %{
          stripe_product_id: "prod_demo_#{pad(i)}",
          name: name,
          description: "Produk demo (sintetis) — bukan objek Stripe asli.",
          active: true
        },
        :unique_stripe_product_id
      )
    end)
  end

  defp seed_prices(count, products) do
    amounts = [0, 4900, 9900, 19_900, 49_900]

    for i <- 1..count do
      product = Enum.at(products, div(i - 1, 2))

      upsert!(
        Price,
        :upsert,
        %{
          stripe_price_id: "price_demo_#{pad(i)}",
          unit_amount: Enum.at(amounts, rem(i, length(amounts))),
          currency: "usd",
          recurring_interval: if(rem(i, 2) == 0, do: "month", else: nil),
          active: true,
          product_id: product.id
        },
        :unique_stripe_price_id
      )
    end
  end

  defp seed_customers(count, users) do
    users
    |> Enum.take(count)
    |> Enum.with_index(1)
    |> Enum.map(fn {user, i} ->
      upsert!(
        Customer,
        :upsert,
        %{
          stripe_customer_id: "cus_demo_#{pad(i)}",
          user_id: user.id,
          # User.email adalah :ci_string — ambil string mentahnya (lihat
          # Josjob.Accounts.Validations.WorkEmailForOrganization).
          email: Ash.CiString.value(user.email)
        },
        :unique_stripe_customer_id
      )
    end)
  end

  defp seed_subscriptions(count, customers, prices) do
    for i <- 1..count do
      customer = Enum.at(customers, rem(i - 1, length(customers)))
      price = Enum.at(prices, rem(i - 1, length(prices)))

      upsert!(
        Subscription,
        :upsert,
        %{
          stripe_subscription_id: "sub_demo_#{pad(i)}",
          status: if(rem(i, 10) == 0, do: "past_due", else: "active"),
          stripe_price_id: price.stripe_price_id,
          current_period_end: DateTime.add(DateTime.utc_now(), 30 * 86_400, :second),
          cancel_at_period_end: false,
          customer_id: customer.id
        },
        :unique_stripe_subscription_id
      )
    end
    |> length()
  end

  defp seed_payments(count, customers, prices) do
    for i <- 1..count do
      customer = Enum.at(customers, rem(i - 1, length(customers)))
      price = Enum.at(prices, rem(i - 1, length(prices)))

      upsert!(
        Payment,
        :upsert,
        %{
          stripe_payment_intent_id: "pi_demo_#{pad(i)}",
          amount: price.unit_amount,
          currency: "usd",
          status: "succeeded",
          description: "Pembayaran demo (sintetis).",
          metadata: %{"demo" => true},
          customer_id: customer.id
        },
        :unique_stripe_payment_intent_id
      )
    end
    |> length()
  end

  # ---- joins -------------------------------------------------------------------

  defp seed_section_orgs(count, sections, orgs) do
    wanted =
      for {section, si} <- Enum.with_index(sections),
          k <- [0, 1],
          do: {section, Enum.at(orgs, rem(si + k * 5, length(orgs)))}

    wanted
    |> Enum.take(count)
    |> Enum.map(fn {section, org} ->
      upsert!(
        SectionOrganization,
        :create,
        %{section_id: section.id, organization_id: org.id},
        :unique_section_organization
      )
    end)
    |> length()
  end

  defp seed_course_orgs(count, courses, course_orgs) do
    courses
    |> Enum.zip(course_orgs)
    |> Enum.take(count)
    |> Enum.map(fn {course, org} ->
      upsert!(
        CourseOrganization,
        :create,
        %{course_id: course.id, organization_id: org.id},
        :unique_course_organization
      )
    end)
    |> length()
  end

  defp seed_course_industries(count, courses) do
    industries = Industry |> Ash.read!(authorize?: false)
    per_course = div(count, length(courses))
    extra = rem(count, length(courses))

    courses
    |> Enum.with_index()
    |> Enum.flat_map(fn {course, ci} ->
      n = per_course + if ci < extra, do: 1, else: 0

      for k <- 0..(n - 1) do
        industry = Enum.at(industries, rem(ci + k * 3, length(industries)))

        upsert!(
          CourseIndustry,
          :create,
          %{course_id: course.id, industry_id: industry.id},
          :unique_course_industry
        )
      end
    end)
    |> length()
  end
end
