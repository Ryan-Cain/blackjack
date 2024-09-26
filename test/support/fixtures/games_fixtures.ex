defmodule Blackjack.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Blackjack.Games` context.
  """

  @doc """
  Generate a table.
  """
  def table_fixture(attrs \\ %{}) do
    {:ok, table} =
      attrs
      |> Enum.into(%{
        countdown: 42,
        name: "some name",
        table_color: "some table_color",
        table_min: 42
      })
      |> Blackjack.Games.create_table()

    table
  end
end
