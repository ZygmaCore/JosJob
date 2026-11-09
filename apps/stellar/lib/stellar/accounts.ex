defmodule Stellar.Accounts do
  use Ash.Domain

  resources do
    resource(Stellar.Accounts.User)
    resource(Stellar.Accounts.Token)
    resource(Stellar.Accounts.UserIdentity)
    resource(Stellar.Accounts.UserDetail)
    resource(Stellar.Accounts.Profile)
  end
end
