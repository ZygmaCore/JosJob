defmodule Josjob.Orgs do
  @moduledoc "Domain tenant: organizations, industries, memberships."
  use Ash.Domain

  resources do
    resource(Josjob.Orgs.Organization)
    resource(Josjob.Orgs.Industry)
    resource(Josjob.Orgs.Membership)
    resource(Josjob.Orgs.Country)
    resource(Josjob.Orgs.Skill)
    resource(Josjob.Orgs.Profession)
  end
end
