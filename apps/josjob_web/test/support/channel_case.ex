defmodule JosjobWeb.ChannelCase do
  @moduledoc """
  Test case untuk channel (`Phoenix.ChannelTest`). LiveRoomChannel tidak menyentuh
  DB, jadi tidak ada sandbox Ecto di sini.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint JosjobWeb.Endpoint

      import Phoenix.ChannelTest
      import JosjobWeb.ChannelCase
    end
  end
end
