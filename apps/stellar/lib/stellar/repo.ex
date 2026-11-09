defmodule Stellar.Repo do
  use AshPostgres.Repo,
    otp_app: :stellar,
    warn_on_missing_ash_functions?: false

  # citext -> email case-insensitive (Ash :ci_string).
  def installed_extensions do
    ["citext"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
