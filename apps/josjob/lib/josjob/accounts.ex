defmodule Josjob.Accounts do
  use Ash.Domain

  resources do
    resource(Josjob.Accounts.User)
    resource(Josjob.Accounts.Token)
    resource(Josjob.Accounts.UserIdentity)
    resource(Josjob.Accounts.UserDetail)
    resource(Josjob.Accounts.Profile)
  end
end
