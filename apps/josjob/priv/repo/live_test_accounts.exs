# Akun live-test: SATU akun per role sistem, buat testing organik di dev.
#
# Jalankan dari ROOT repo:
#
#     mix run apps/josjob/priv/repo/live_test_accounts.exs
#
# Membuat (idempotent — aman di-run ulang):
#
#   * employer@dev.test     — role employer
#   * coordinator@dev.test  — role coordinator
#   * teacher@dev.test      — role teacher
#   * worker@dev.test       — role worker
#   * graduate@dev.test     — role graduate
#
# Password semua akun: "admin123".
#
# Tiap akun jadi member :active di org "Atveti" (org awal dari
# `Josjob.Release.seed/0`) dengan SATU MembershipRole. Script ini memanggil
# `Josjob.Release.seed()` dulu, jadi superuser, org Atveti, RBAC, dan master
# data selalu ada sebelum akun dibuat.
#
# Superuser TIDAK dibuat di sini — sudah ada dari Release.seed (default
# superuser@gmail.com / superuser123, atau dari env SEED_SUPERUSER_EMAIL /
# SEED_SUPERUSER_PASSWORD).
#
# BEDA dengan demo seed (`demo_seeds.exs`): script ini TIDAK membuat 1000
# baris data demo — hanya 5 akun + 5 membership + 5 membership_role.
# Seperti demo seed, script ini TIDAK dipanggil otomatis oleh
# `mix ecto.setup` / `Josjob.Release.seed/0`; jalankan eksplisit di dev.
#
# Catatan: run ulang TIDAK me-reset password. Bila password sebuah akun
# sudah diubah manual, akun itu tetap pakai password yang diubah.
#
# BELUM dieksekusi di VM ini (tidak ada Elixir/Docker di sini) — jalankan
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

roles = ["employer", "coordinator", "teacher", "worker", "graduate"]
password = "admin123"

accounts =
  for role <- roles do
    email = "#{role}@dev.test"

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read!(authorize?: false)
      |> List.first() ||
        (User
         |> Ash.Changeset.for_create(:register_with_email, %{
           email: email,
           full_name: "#{String.capitalize(role)} Live Test",
           password: password,
           account_type: :personal
         })
         |> Ash.create!(authorize?: false))

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
Live-test accounts selesai (5 akun, org Atveti, password semua: #{password}).
#{Enum.map_join(accounts, "\n  ", fn {role, email} -> "#{role}: #{email}" end)}
  Superuser (sudah ada dari Release.seed): superuser@gmail.com / superuser123
""")
