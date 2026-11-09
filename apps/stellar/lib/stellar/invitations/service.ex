defmodule Stellar.Invitations.Service do
  @moduledoc """
  Orkestrasi undangan teacher — dipanggil dari controller JSON.

  - `list/0` — semua undangan (tampilan superuser), termuat organisasinya.
  - `invite/1` — buat undangan + kirim email; bila sudah ada undangan `:pending`
    untuk (email, org) yang sama → kirim ulang (reuse), bukan duplikat.
  - `resend/1` — kirim ulang undangan (by id).
  - `get_by_token/1` — validasi token (pending & belum kedaluwarsa) untuk halaman accept.
  - `accept/2` — buat/pakai user, beri membership aktif + role, tandai diterima.
    User BARU → langsung diterbitkan token sesi (login). User yang sudah ada →
    hanya di-provision (tanpa auto-login, hindari bypass password).
  """
  require Ash.Query
  require Logger

  alias Stellar.Accounts.{Tokens, User}
  alias Stellar.Invitations.{Email, Invitation}
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Provisioning}

  @email_re ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/

  # --- listing -------------------------------------------------------------

  @doc "Semua undangan (urut terbaru), dengan organisasi termuat."
  def list do
    Invitation
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:organization], authorize?: false)
  end

  # --- invite --------------------------------------------------------------

  @doc """
  Undang `email` ke `organization_id` sebagai `role_key` (default teacher).
  Reuse+resend bila sudah ada undangan pending untuk (email, org).
  Return `{:ok, invitation}` | `{:error, reason}`.
  """
  def invite(attrs) do
    email = normalize_email(get(attrs, :email))
    org_id = get(attrs, :organization_id)
    role_key = get(attrs, :role_key) || "teacher"
    invited_by_id = get(attrs, :invited_by_id)

    cond do
      email in [nil, ""] -> {:error, :email_required}
      not valid_email?(email) -> {:error, :invalid_email}
      is_nil(org_id) -> {:error, :organization_required}
      not org_exists?(org_id) -> {:error, :organization_not_found}
      true -> upsert_invite(email, org_id, role_key, invited_by_id)
    end
  end

  defp upsert_invite(email, org_id, role_key, invited_by_id) do
    case existing_pending(email, org_id) do
      nil -> create_and_send(email, org_id, role_key, invited_by_id)
      invite -> do_resend(invite)
    end
  end

  defp create_and_send(email, org_id, role_key, invited_by_id) do
    case Invitation
         |> Ash.Changeset.for_create(:create, %{
           email: email,
           organization_id: org_id,
           role_key: role_key,
           invited_by_id: invited_by_id
         })
         |> Ash.create(authorize?: false) do
      {:ok, invite} ->
        invite = Ash.load!(invite, [:organization], authorize?: false)
        # Email is best-effort: the invitation IS created & listed either way;
        # a mailer failure must not fail the request (see deliver/1).
        _ = deliver(invite)
        {:ok, invite}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- resend --------------------------------------------------------------

  @doc "Kirim ulang undangan `id`."
  def resend(id) when is_binary(id) do
    case fetch(id) do
      nil -> {:error, :not_found}
      invite -> do_resend(invite)
    end
  end

  defp do_resend(invite) do
    case invite |> Ash.Changeset.for_update(:resend, %{}) |> Ash.update(authorize?: false) do
      {:ok, updated} ->
        updated = Ash.load!(updated, [:organization], authorize?: false)
        _ = deliver(updated)
        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- token lookup (public) ----------------------------------------------

  @doc "Undangan pending & valid untuk `token` (halaman accept), atau error."
  def get_by_token(token) when is_binary(token) and token != "" do
    case by_token(token) do
      nil -> {:error, :not_found}
      %{status: :accepted} -> {:error, :already_accepted}
      %{status: :revoked} -> {:error, :revoked}
      invite -> if expired?(invite), do: {:error, :expired}, else: {:ok, load_org(invite)}
    end
  end

  def get_by_token(_), do: {:error, :not_found}

  # --- accept --------------------------------------------------------------

  @doc """
  Terima undangan `token` dan buat/gabungkan akun teacher.

  Return:
    - `{:ok, %{user, tokens, new: true}}`  → user baru dibuat + login.
    - `{:ok, %{user, tokens: nil, new: false}}` → email sudah punya akun; hanya
      di-provision role (tak auto-login — klien arahkan ke login biasa).
  """
  def accept(token, %{full_name: full_name, password: password})
      when is_binary(full_name) and is_binary(password) do
    with {:ok, invite} <- get_by_token(token) do
      email = to_string(invite.email)

      case find_user(email) do
        nil -> provision_new(invite, email, full_name, password)
        user -> provision_existing(invite, user)
      end
    end
  end

  def accept(_token, _attrs), do: {:error, :invalid_params}

  defp provision_new(invite, email, full_name, password) do
    Stellar.Repo.transaction(fn ->
      user =
        User
        |> Ash.Changeset.for_create(:register_with_email, %{
          email: email,
          full_name: full_name,
          password: password
        })
        |> Ash.create!(authorize?: false)
        # Teacher diundang admin → lewati onboarding, langsung ke dashboard.
        |> then(fn u ->
          u
          |> Ash.Changeset.for_update(:update_onboarding, %{
            progress: 100,
            mandatory_completed: true
          })
          |> Ash.update!(authorize?: false)
        end)

      provision_role!(invite, user)
      user
    end)
    |> case do
      {:ok, user} ->
        {:ok, tokens} = Tokens.issue_pair(user)
        {:ok, %{user: user, tokens: tokens, new: true}}

      {:error, reason} ->
        {:error, provisioning_error(reason)}
    end
  end

  defp provision_existing(invite, user) do
    Stellar.Repo.transaction(fn ->
      provision_role!(invite, user)
      user
    end)
    |> case do
      {:ok, user} -> {:ok, %{user: user, tokens: nil, new: false}}
      {:error, reason} -> {:error, provisioning_error(reason)}
    end
  end

  # Membership aktif + role sistem + tandai undangan diterima. Idempoten.
  defp provision_role!(invite, user) do
    membership = ensure_membership!(user.id, invite.organization_id)
    role = Provisioning.ensure_org_role!(invite.organization_id, invite.role_key || "teacher")
    ensure_membership_role!(membership.id, role.id)
    mark_accepted!(invite, user.id)
  end

  defp ensure_membership!(user_id, org_id) do
    case Membership
         |> Ash.Query.filter(user_id == ^user_id and organization_id == ^org_id)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        Membership
        |> Ash.Changeset.for_create(:create, %{
          user_id: user_id,
          organization_id: org_id,
          status: :active
        })
        |> Ash.create!(authorize?: false)

      %{status: :active} = m ->
        m

      m ->
        m
        |> Ash.Changeset.for_update(:update, %{status: :active})
        |> Ash.update!(authorize?: false)
    end
  end

  defp ensure_membership_role!(membership_id, role_id) do
    case MembershipRole
         |> Ash.Query.filter(membership_id == ^membership_id and role_id == ^role_id)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        MembershipRole
        |> Ash.Changeset.for_create(:create, %{membership_id: membership_id, role_id: role_id})
        |> Ash.create!(authorize?: false)

      mr ->
        mr
    end
  end

  defp mark_accepted!(invite, user_id) do
    invite
    |> Ash.Changeset.for_update(:accept, %{user_id: user_id})
    |> Ash.update!(authorize?: false)
  end

  # --- email ---------------------------------------------------------------

  # Best-effort email delivery. Logs the accept link (so the flow is usable/
  # testable even when no mailer is configured — e.g. the prod release used for
  # local dev, where Swoosh's Local adapter storage isn't running) and NEVER
  # raises/exits: a mailer misconfiguration must not fail invitation creation.
  defp deliver(invite) do
    org_name = (invite.organization && invite.organization.name) || "Stellar"
    Logger.info("Invitation #{invite.id} → #{invite.email}: #{Email.accept_url(invite.token)}")

    try do
      case invite |> Email.invitation(org_name) |> Stellar.Mailer.deliver() do
        {:ok, _meta} ->
          :ok

        {:error, reason} ->
          Logger.warning("Invitation email not sent (#{invite.id}): #{inspect(reason)}")
          {:error, :email_failed}
      end
    rescue
      e ->
        Logger.warning("Invitation email raised (#{invite.id}): #{inspect(e)}")
        {:error, :email_failed}
    catch
      kind, reason ->
        Logger.warning("Invitation email #{kind} (#{invite.id}): #{inspect(reason)}")
        {:error, :email_failed}
    end
  end

  # --- queries / helpers ---------------------------------------------------

  defp existing_pending(email, org_id) do
    Invitation
    |> Ash.Query.filter(email == ^email and organization_id == ^org_id and status == :pending)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp fetch(id) do
    case Ash.get(Invitation, id, authorize?: false) do
      {:ok, invite} -> invite
      _ -> nil
    end
  end

  defp by_token(token) do
    Invitation
    |> Ash.Query.filter(token == ^token)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp load_org(invite), do: Ash.load!(invite, [:organization], authorize?: false)

  defp find_user(email) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp org_exists?(org_id) do
    match?({:ok, _}, Ash.get(Organization, org_id, authorize?: false))
  end

  defp expired?(%{expires_at: nil}), do: false
  defp expired?(%{expires_at: at}), do: DateTime.compare(DateTime.utc_now(), at) == :gt

  defp valid_email?(email), do: Regex.match?(@email_re, email)

  defp normalize_email(nil), do: nil

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(email), do: email |> to_string() |> normalize_email()

  defp get(attrs, key) when is_atom(key) do
    Map.get(attrs, key) || Map.get(attrs, to_string(key))
  end

  # Ash bang funcs raise; Repo.transaction membungkus jadi {:error, reason}.
  defp provisioning_error(%Ash.Error.Invalid{} = e), do: e
  defp provisioning_error(reason), do: reason
end
