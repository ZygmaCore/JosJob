defmodule StellarWeb.ChannelCase do
  @moduledoc """
  Test case untuk channel (`Phoenix.ChannelTest`). LiveRoomChannel tidak menyentuh
  DB, jadi tidak ada sandbox Ecto di sini.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint StellarWeb.Endpoint

      import Phoenix.ChannelTest
      import StellarWeb.ChannelCase
    end
  end
end
