defmodule Josjob.Invitations.Email do
  @moduledoc """
  Pembuat email undangan teacher (Swoosh). Di dev, adapter `Local` menyimpan email
  ke mailbox yang bisa dilihat di `/dev/mailbox`.

  Tautan accept mengarah ke app Flutter: `<fe_base_url>/invite?token=<token>`.
  `fe_base_url` dikonfigurasi via `config :josjob, :fe_base_url` (env `FE_BASE_URL`).
  """
  import Swoosh.Email

  @doc "Bangun `Swoosh.Email` undangan untuk `invitation` (butuh org_name utk konteks)."
  def invitation(invitation, org_name) do
    accept_url = accept_url(invitation.token)
    to_addr = to_string(invitation.email)

    new()
    |> to(to_addr)
    |> from(from_address())
    |> subject("You're invited to teach on Josjob")
    |> html_body(render_html(org_name, accept_url))
    |> text_body(render_text(org_name, accept_url))
  end

  @doc """
  URL accept (dibuka di app Flutter). Memakai HASH route (`/#/invite?...`) karena
  build web memakai strategi URL hash default (bukan path). Tanpa `#`, path
  `/invite` di-SPA-fallback ke index.html tapi Flutter membaca rute dari fragment
  → jadi rute '/' (landing), bukan halaman accept.
  """
  def accept_url(token) when is_binary(token) do
    base = String.trim_trailing(fe_base_url(), "/")
    "#{base}/#/invite?token=#{URI.encode_www_form(token)}"
  end

  defp render_html(org_name, accept_url) do
    """
    <div style="font-family:Arial,Helvetica,sans-serif;max-width:520px;margin:auto;color:#1f2937">
      <h2 style="color:#111827">You've been invited to teach on Josjob</h2>
      <p>You've been invited to join <strong>#{escape(org_name)}</strong> as a <strong>Teacher</strong>.</p>
      <p>Click the button below to create your teacher account.</p>
      <p style="margin:28px 0">
        <a href="#{accept_url}"
           style="background:#4f46e5;color:#fff;text-decoration:none;padding:12px 22px;border-radius:8px;display:inline-block;font-weight:600">
          Accept invitation
        </a>
      </p>
      <p style="font-size:13px;color:#6b7280">Or paste this link into your browser:<br>
        <a href="#{accept_url}" style="color:#4f46e5">#{accept_url}</a>
      </p>
      <p style="font-size:12px;color:#9ca3af;margin-top:28px">
        This invitation will expire. If you didn't expect it, you can ignore this email.
      </p>
    </div>
    """
  end

  defp render_text(org_name, accept_url) do
    """
    You've been invited to join #{org_name} as a Teacher on Josjob.

    Create your teacher account here:
    #{accept_url}

    If you didn't expect this invitation, you can ignore this email.
    """
  end

  defp from_address do
    Application.get_env(:josjob, :mail_from, {"JosJob", "no-reply@josjob.local"})
  end

  defp fe_base_url do
    Application.get_env(:josjob, :fe_base_url, "http://localhost:8081")
  end

  defp escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp escape(value), do: escape(to_string(value))
end
