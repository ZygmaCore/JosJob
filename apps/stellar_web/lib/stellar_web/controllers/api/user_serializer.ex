defmodule StellarWeb.Api.UserSerializer do
  @moduledoc """
  Bentuk JSON `user` yang KONSISTEN untuk semua endpoint API (login, register,
  refresh, google, accept undangan). Menyertakan `roles` (key role sistem yang
  diemban user, mis. `["teacher"]`) supaya klien Flutter bisa memilih dashboard
  yang tepat.
  """

  @doc "Serialize `user` ke map JSON."
  def to_json(user) do
    %{
      id: user.id,
      email: to_string(user.email),
      full_name: user.full_name,
      avatar_url: user.avatar_url,
      # nil bila belum dipilih (mis. sign-in Google baru).
      account_type: user.account_type && to_string(user.account_type),
      mandatory_completed: user.mandatory_completed,
      onboarding_progress: user.onboarding_progress,
      is_superuser: user.is_superuser,
      # Key role sistem (union membership aktif) — deteksi peran di klien.
      roles: Stellar.Authz.role_keys(user),
      # Akun organisasi "approved" setelah di-provision admin; lainnya selalu true.
      approved: approved?(user)
    }
  end

  defp approved?(%{account_type: :organization} = user), do: Stellar.Authz.provisioned?(user)
  defp approved?(_user), do: true
end
