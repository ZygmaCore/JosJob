defmodule Josjob.Accounts.AccountType do
  @moduledoc """
  Tipe registrasi akun.

    * `:personal`     — individu. Email bebas (provider apa pun boleh).
    * `:organization` — Corporation atau Institution. WAJIB email kantor —
      provider email gratisan/publik ditolak (lihat
      `Josjob.Accounts.EmailDomains`).

  `nil` (attribute allow_nil?) berarti belum dipilih — mis. akun baru hasil
  sign-in Google yang memilih tipe saat onboarding.
  """
  use Ash.Type.Enum, values: [:personal, :organization]
end
