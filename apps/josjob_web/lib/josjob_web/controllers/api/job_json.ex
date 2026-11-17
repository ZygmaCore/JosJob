defmodule JosjobWeb.Api.JobJSON do
  @moduledoc false
  def listing(job, orgs) do
    org = Enum.find(orgs, &(&1.id == job.organization_id))

    %{
      id: job.id,
      title: job.title,
      description: job.description,
      organization_id: job.organization_id,
      company: job.organization.name,
      location: job.location,
      industry: job.industry,
      employment_type: job.employment_type,
      work_mode: job.work_mode,
      requirements: job.requirements,
      highlights: job.highlights,
      salary_min: job.salary_min,
      salary_max: job.salary_max,
      currency: job.currency,
      salary_period: "month",
      status: job.status,
      synthetic: job.synthetic,
      posted_at: job.posted_at,
      created_at: job.created_at,
      can_manage: not is_nil(org) and org.can_manage
    }
  end
end
