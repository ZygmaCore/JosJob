# Akun live-test: SATU akun per role sistem, buat testing organik di dev.
#
# Jalankan dari ROOT repo:
#
#     mix run apps/josjob/priv/repo/live_test_accounts.exs
#
# Membuat (idempotent — aman di-run ulang):
#
#   * dimassatar2007@gmail.com — role employer
#   * coordinator@dev.test    — role coordinator
#   * alhikam200@gmail.com    — role teacher
#   * worker@dev.test         — role worker
#   * fathan.a.dev@gmail.com  — role graduate (kandidat / job-seeker)
#
# Plus superadmin platform:
#
#   * apasihsh@gmail.com — is_superuser: true
#
# Email ASLI dipakai supaya undangan (dikirim via Resend API) masuk inbox
# beneran, bukan alamat dev.test yang tidak bisa menerima email. TIDAK ada
# role "candidate" di Josjob.Rbac.Catalog — kandidat/job-seeker adalah role
# "graduate". coordinator + worker belum punya email asli, tetap @dev.test.
#
# Password semua akun: "admin123".
#
# Tiap akun role jadi member :active di org "Atveti" (org awal dari
# `Josjob.Release.seed/0`) dengan SATU MembershipRole. Script ini memanggil
# `Josjob.Release.seed()` dulu, jadi superuser, org Atveti, RBAC, dan master
# data selalu ada sebelum akun dibuat.
#
# Superadmin: script ini MEMASTIKAN apasihsh@gmail.com adalah superuser
# (is_superuser: true, pola yang sama dengan Josjob.Release.promote_superuser/2).
# Superuser lama dari Release.seed (superuser@gmail.com) TETAP ada — Release.seed
# mem-promote ulang email dari env SEED_SUPERUSER_EMAIL (default
# superuser@gmail.com) di tiap deploy, jadi menggantinya butuh set
# SEED_SUPERUSER_EMAIL=apasihsh@gmail.com di .env VPS. Superadmin tidak
# diberi membership Atveti — sama seperti superuser dari Release.seed,
# akses penuh didapat lewat is_superuser.
#
# BEDA dengan demo seed (`demo_seeds.exs`): script ini TIDAK membuat 1000
# baris data demo — hanya 5 akun role + 1 superadmin (+ membership/role).
# Seperti demo seed, script ini TIDAK dipanggil otomatis oleh
# `mix ecto.setup` / `Josjob.Release.seed/0`; jalankan eksplisit di dev.
#
# Catatan: run ulang TIDAK me-reset password. Bila password sebuah akun
# sudah diubah manual, akun itu tetap pakai password yang diubah. Password
# superadmin hanya di-backfill bila akun lama belum punya password sama
# sekali (mis. hasil sign-in Google) — tidak pernah menimpa yang sudah ada.
#
# Catatan: akun lama role@dev.test (employer/teacher/graduate) yang dibuat
# run sebelumnya TETAP ada di DB sebagai akun test tambahan — script ini
# membuat akun email-asli sebagai baris BARU, bukan mengganti email akun lama.
#
# BELUM dieksekusi di VM ini (tidak ada Postgres di sini) — jalankan
# sekali di mesin dev dan laporkan error bila ada.

require Ash.Query

alias Josjob.Accounts.User
alias Josjob.Orgs.{Membership, Organization}
alias Josjob.Rbac.{MembershipRole, Role}

{:ok, _} = Application.ensure_all_started(:josjob)

# Base data dulu (superuser, org Atveti, RBAC, master data). Idempotent.
Josjob.Release.seed()

org =
  Organization
  |> Ash.Query.filter(name == "Atveti")
  |> Ash.read!(authorize?: false)
  |> List.first() ||
    raise "Org Atveti tidak ditemukan setelah Josjob.Release.seed()"

password = "admin123"
superadmin_email = "apasihsh@gmail.com"

# Get-or-create user by email (idempotent). Dipakai akun role + superadmin.
ensure_user = fn email, full_name ->
  User
  |> Ash.Query.filter(email == ^email)
  |> Ash.read!(authorize?: false)
  |> List.first() ||
    User
    |> Ash.Changeset.for_create(:register_with_email, %{
      email: email,
      full_name: full_name,
      password: password,
      account_type: :personal
    })
    |> Ash.create!(authorize?: false)
end

# Superadmin platform — pola yang sama dengan Josjob.Release.promote_superuser/2:
# :update menerima is_superuser (ada di default_accept User); mandatory_completed
# + onboarding_progress harus via force_change_attribute; password hanya
# di-backfill bila akun lama belum punya (tidak pernah me-reset password).
superadmin = ensure_user.(superadmin_email, "Super Admin Live Test")

superadmin_changeset =
  superadmin
  |> Ash.Changeset.for_update(:update, %{is_superuser: true})
  |> Ash.Changeset.force_change_attribute(:mandatory_completed, true)
  |> Ash.Changeset.force_change_attribute(:onboarding_progress, 100)

superadmin_changeset =
  if is_nil(superadmin.hashed_password) do
    Ash.Changeset.force_change_attribute(
      superadmin_changeset,
      :hashed_password,
      Bcrypt.hash_pwd_salt(password)
    )
  else
    superadmin_changeset
  end

Ash.update!(superadmin_changeset, authorize?: false)

# Role -> email asli (biar undangan via Resend masuk inbox beneran).
# coordinator + worker belum punya email asli, tetap @dev.test.
role_emails = [
  {"employer", "dimassatar2007@gmail.com"},
  {"coordinator", "coordinator@dev.test"},
  {"teacher", "alhikam200@gmail.com"},
  {"worker", "worker@dev.test"},
  {"graduate", "fathan.a.dev@gmail.com"}
]

accounts =
  for {role, email} <- role_emails do
    user = ensure_user.(email, "#{String.capitalize(role)} Live Test")

    membership =
      Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: user.id,
        organization_id: org.id,
        status: :active
      })
      |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_user_org)

    role_row =
      Role
      |> Ash.Query.filter(organization_id == ^org.id and key == ^role)
      |> Ash.read!(authorize?: false)
      |> List.first() ||
        raise "Role #{role} belum di-provision untuk org Atveti"

    MembershipRole
    |> Ash.Changeset.for_create(:create, %{
      membership_id: membership.id,
      role_id: role_row.id
    })
    |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :unique_membership_role)

    {role, email}
  end

IO.puts("""
Live-test accounts selesai (5 role + 1 superadmin, org Atveti, password: #{password}).
#{Enum.map_join(accounts, "\n  ", fn {role, email} -> "#{role}: #{email}" end)}
  superadmin: #{superadmin_email} (is_superuser: true)
""")
