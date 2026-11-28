defmodule JosjobLrn.Learning.Changes.CheckCapacity do
  @moduledoc """
  Tolak enrollment bila kelas penuh. `capacity` nil = tak terbatas. Hitung
  enrollment berstatus :active di kelas tsb; error bila count >= capacity.
  (Belum ada row-lock; race saat konkuren tinggi diterima untuk slice ini.)
  """
  use Ash.Resource.Change
  require Ash.Query

  alias JosjobLrn.Learning.{Class, Enrollment}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn cs ->
      class_id = Ash.Changeset.get_attribute(cs, :class_id)

      with false <- is_nil(class_id),
           {:ok, %Class{capacity: capacity}} when not is_nil(capacity) <-
             Ash.get(Class, class_id, authorize?: false) do
        active =
          Enrollment
          |> Ash.Query.filter(class_id == ^class_id and status == :active)
          |> Ash.count!(authorize?: false)

        if active >= capacity do
          Ash.Changeset.add_error(cs, field: :class_id, message: "class is full")
        else
          cs
        end
      else
        _ -> cs
      end
    end)
  end
end
