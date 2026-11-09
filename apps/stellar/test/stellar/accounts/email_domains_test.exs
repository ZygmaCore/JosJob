defmodule Stellar.Accounts.EmailDomainsTest do
  use ExUnit.Case, async: true

  alias Stellar.Accounts.EmailDomains

  describe "free_provider?/1" do
    test "flags common free/public webmail providers" do
      for email <-
            ~w(a@gmail.com b@yahoo.com c@hotmail.com d@outlook.com e@icloud.com f@proton.me g@aol.com) do
        assert EmailDomains.free_provider?(email), "expected #{email} to be a free provider"
      end
    end

    test "does not flag work/company/institution domains" do
      for email <- ~w(hr@acme.com dev@sub.company.co.id staff@university.edu person@kantor.co.id) do
        refute EmailDomains.free_provider?(email), "expected #{email} to be a work email"
      end
    end

    test "is case- and whitespace-insensitive" do
      assert EmailDomains.free_provider?("  Foo@GMAIL.com ")
    end

    test "ignores the local part (plus-addressing)" do
      assert EmailDomains.free_provider?("foo+work@gmail.com")
    end

    test "malformed / missing emails are not free providers" do
      refute EmailDomains.free_provider?("not-an-email")
      refute EmailDomains.free_provider?("@gmail.com")
      refute EmailDomains.free_provider?("")
      refute EmailDomains.free_provider?(nil)
    end

    test "canonicalizes a trailing-dot FQDN (gmail.com. is still gmail)" do
      assert EmailDomains.free_provider?("hr@gmail.com.")
      assert EmailDomains.domain("hr@gmail.com.") == "gmail.com"
    end

    test "a domain with internal whitespace or extra @ is malformed" do
      assert is_nil(EmailDomains.domain("hr@gmail .com"))
      assert is_nil(EmailDomains.domain("a@b@gmail.com"))
    end
  end

  describe "work_email?/1" do
    test "true for company domains, false for free and malformed" do
      assert EmailDomains.work_email?("hr@acme.com")
      refute EmailDomains.work_email?("hr@gmail.com")
      refute EmailDomains.work_email?("garbage")
    end
  end
end
