defmodule Josjob.Accounts.Token do
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    domain: Josjob.Accounts

  postgres do
    table("tokens")
    repo(Josjob.Repo)
  end
end
