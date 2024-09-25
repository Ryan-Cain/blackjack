defmodule Blackjack.TablesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Blackjack.Tables` context.
  """

  @doc """
  Generate a player.
  """
  def player_fixture(attrs \\ %{}) do
    {:ok, player} =
      attrs
      |> Enum.into(%{
        chip_count: 42,
        hands_played: 42,
        hands_won: 42,
        name: "some name"
      })
      |> Blackjack.Tables.create_player()

    player
  end
end
