defmodule Stellar.Accounts.UserIdentity do
  use Ash.Resource,
    otp_app: :stellar,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.UserIdentity],
    domain: Stellar.Accounts

  user_identity do
    user_resource(Stellar.Accounts.User)
    uid_attribute_name(:uid)
    strategy_attribute_name(:strategy)
    user_id_attribute_name(:user_id)
    access_token_attribute_name(:access_token)
  end

  # created_at = kapan identity ditautkan; updated_at = jejak refresh token /
  # login terakhir per provider (baris di-upsert tiap login).
  attributes do
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  postgres do
    table("user_identities")
    repo(Stellar.Repo)
  end
end
