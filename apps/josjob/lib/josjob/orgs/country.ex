defmodule Josjob.Orgs.Country do
  @moduledoc "Master data negara (ISO 3166-1). `code` = alpha-2 huruf besar, unik."
  use Ash.Resource,
    otp_app: :josjob,
    data_layer: AshPostgres.DataLayer,
    domain: Josjob.Orgs

  postgres do
    table("countries")
    repo(Josjob.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:code, :string, allow_nil?: false, public?: true)
    # Kode panggil telepon E.164, mis. "+62" (Indonesia). Nullable.
    attribute(:phone_code, :string, allow_nil?: true, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  # Pastikan `code` selalu huruf besar.
  changes do
    change(
      fn changeset, _ ->
        case Ash.Changeset.get_attribute(changeset, :code) do
          code when is_binary(code) ->
            Ash.Changeset.change_attribute(changeset, :code, String.upcase(code))

          _ ->
            changeset
        end
      end,
      on: [:create, :update]
    )
  end

  identities do
    identity(:unique_code, [:code])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:name, :code, :phone_code])
  end
end
