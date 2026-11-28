defmodule JosjobWeb.Audit do
  @moduledoc """
  Helper audit-trail untuk halaman admin.

  `user_labels/0` mengembalikan peta `%{user_id => email}` untuk menampilkan
  kolom `created_by` / `updated_by` (yang menyimpan id user) sebagai email.
  """
  alias Josjob.Accounts.User

  @doc "Peta id user -> email, untuk resolusi kolom created_by/updated_by."
  def user_labels do
    User
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, to_string(&1.email)})
  end
end
