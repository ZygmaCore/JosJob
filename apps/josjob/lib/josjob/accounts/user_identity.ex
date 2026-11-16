defmodule Josjob.Accounts.UserIdentity do
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.UserIdentity],
    domain: Josjob.Accounts

  user_identity do
    user_resource(Josjob.Accounts.User)
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
    repo(Josjob.Repo)
  end
end
