defmodule Stellar.Accounts.EmailDomains do
  @moduledoc """
  Mengklasifikasikan alamat email berdasarkan providernya agar akun Corporation/
  Institution (`:organization`) bisa diwajibkan memakai email KANTOR.

  "Email kantor" didefinisikan secara negatif: alamat apa pun yang domain-nya
  BUKAN provider webmail gratisan/publik yang dikenal. Tidak ada cara andal untuk
  membuktikan sebuah alamat benar-benar korporat, jadi blocklist terkurasi adalah
  pendekatan yang paling praktis.

  Daftar bisa ditimpa/ditambah saat runtime lewat config:

      config :stellar, :free_email_domains, ~w(gmail.com contoh.com)
  """

  # Provider webmail konsumen yang umum. Selalu lower-case; dicocokkan persis
  # dengan bagian domain dari email.
  @free_domains ~w(
    gmail.com googlemail.com
    yahoo.com yahoo.co.id yahoo.co.uk yahoo.co.jp yahoo.fr yahoo.de yahoo.es yahoo.it ymail.com rocketmail.com
    outlook.com outlook.co.id hotmail.com hotmail.co.uk hotmail.co.id hotmail.fr live.com live.co.uk live.com.au msn.com
    icloud.com me.com mac.com
    aol.com
    proton.me protonmail.com pm.me
    gmx.com gmx.net gmx.de
    mail.com email.com usa.com
    yandex.com yandex.ru
    zoho.com zohomail.com
    hey.com
    tutanota.com tuta.io tutamail.com
    fastmail.com
    aim.com
    gawab.com
    hushmail.com
    mailinator.com
  )

  @doc """
  Mengembalikan bagian domain (lower-case, terkanonikalisasi) dari `email`, atau
  `nil` bila malformed. Kanonikalisasi mencegah bypass blocklist: mis. FQDN
  bertitik-akhir `gmail.com.` disamakan dengan `gmail.com`, dan domain yang
  mengandung spasi/tab (atau kosong) dianggap malformed.
  """
  @spec domain(term()) :: String.t() | nil
  def domain(email) when is_binary(email) do
    case email |> String.trim() |> String.downcase() |> String.split("@") do
      [local, d] when local != "" and d != "" ->
        canonical = String.trim_trailing(d, ".")

        if canonical == "" or String.contains?(canonical, [" ", "\t"]),
          do: nil,
          else: canonical

      _ ->
        nil
    end
  end

  def domain(_), do: nil

  @doc "True bila `email` termasuk provider webmail gratisan/publik yang dikenal."
  @spec free_provider?(term()) :: boolean()
  def free_provider?(email) do
    case domain(email) do
      nil -> false
      d -> d in free_domains()
    end
  end

  @doc """
  True bila `email` adalah email kantor (bukan provider gratisan). Email malformed
  (tanpa domain yang valid) BUKAN email kantor.
  """
  @spec work_email?(term()) :: boolean()
  def work_email?(email) do
    case domain(email) do
      nil -> false
      d -> d not in free_domains()
    end
  end

  @doc "Daftar domain gratisan yang berlaku (config override, fallback ke bawaan)."
  @spec free_domains() :: [String.t()]
  def free_domains do
    case Application.get_env(:stellar, :free_email_domains) do
      list when is_list(list) -> Enum.map(list, &String.downcase/1)
      _ -> @free_domains
    end
  end
end
