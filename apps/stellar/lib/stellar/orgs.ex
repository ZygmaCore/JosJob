defmodule Stellar.Orgs do
  @moduledoc "Domain tenant: organizations, industries, memberships."
  use Ash.Domain

  resources do
    resource(Stellar.Orgs.Organization)
    resource(Stellar.Orgs.Industry)
    resource(Stellar.Orgs.Membership)
    resource(Stellar.Orgs.Country)
    resource(Stellar.Orgs.Skill)
    resource(Stellar.Orgs.Profession)
  end
end
