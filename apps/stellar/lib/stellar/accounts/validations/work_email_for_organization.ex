defmodule Stellar.Accounts.Validations.WorkEmailForOrganization do
  @moduledoc """
  Memastikan akun Corporation/Institution (`account_type == :organization`)
  mendaftar dengan email KANTOR. Akun personal (dan tipe yang belum dipilih /
  `nil`) menerima email apa pun. Lihat `Stellar.Accounts.EmailDomains`.

  Berlaku baik saat create (register) maupun update (set tipe akun via
  onboarding untuk pengguna Google).
  """
  use Ash.Resource.Validation

  alias Stellar.Accounts.EmailDomains

  @impl true
  def validate(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :account_type) == :organization do
      email = changeset |> Ash.Changeset.get_attribute(:email) |> email_to_string()

      # Positive requirement: the email must BE a work email. This rejects free
      # providers AND malformed/unparseable domains (which are not work emails).
      if EmailDomains.work_email?(email) do
        :ok
      else
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: :email,
           message:
             "must be a work email — corporation or institution accounts cannot use a free email provider"
         )}
      end
    else
      :ok
    end
  end

  # `email` disimpan sebagai ci_string; ambil nilai string mentahnya.
  defp email_to_string(%Ash.CiString{} = ci), do: Ash.CiString.value(ci)
  defp email_to_string(v) when is_binary(v), do: v
  defp email_to_string(_), do: ""
end
