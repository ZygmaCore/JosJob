defmodule Stellar.Invitations do
  @moduledoc """
  Domain **Invitations** — undangan berbasis email untuk bergabung ke sebuah
  organisasi dengan sebuah role sistem (mis. `teacher`).

  Alur (lihat `Stellar.Invitations.Service` untuk orkestrasi):

    1. Superuser mengundang sebuah email ke organisasi pilihannya sebagai teacher
       → baris `Invitation` (status `:pending`, token acak, masa berlaku) dibuat &
       email berisi tautan accept dikirim (Swoosh).
    2. Undangan yang masih `:pending` bisa dikirim ulang (resend).
    3. Penerima membuka tautan, membuat akun (email+password) → user dibuat,
       diberi membership aktif + role `teacher` di org tsb, undangan `:accepted`.

  Resource `authorize?: false` (enforcement di web-layer, konsisten dgn RBAC lain).
  """
  use Ash.Domain, otp_app: :stellar

  resources do
    resource(Stellar.Invitations.Invitation)
  end
end
