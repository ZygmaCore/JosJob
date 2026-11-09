defmodule Stellar.Accounts.Token do
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    domain: Stellar.Accounts

  postgres do
    table("tokens")
    repo(Stellar.Repo)
  end
end
