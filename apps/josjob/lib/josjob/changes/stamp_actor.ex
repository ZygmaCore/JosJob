defmodule Josjob.Changes.StampActor do
  @moduledoc """
  Audit trail. Mengisi `created_by` (saat create) dan `updated_by`
  (create + update) dari `actor.id` — user yang menjalankan aksi.

  Tanpa actor (mis. seed / operasi sistem) kolom dibiarkan apa adanya (nil).
  Dipakai oleh resource lewat `change Josjob.Changes.StampActor`.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    case actor_id(context) do
      nil ->
        changeset

      id ->
        changeset
        |> stamp_created(id)
        |> Ash.Changeset.force_change_attribute(:updated_by, id)
    end
  end

  defp stamp_created(%{action_type: :create} = changeset, id),
    do: Ash.Changeset.force_change_attribute(changeset, :created_by, id)

  defp stamp_created(changeset, _id), do: changeset

  defp actor_id(%{actor: %{id: id}}), do: id
  defp actor_id(_), do: nil
end
