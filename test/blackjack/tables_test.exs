defmodule Blackjack.TablesTest do
  use Blackjack.DataCase

  alias Blackjack.Tables

  describe "players" do
    alias Blackjack.Tables.Player

    import Blackjack.TablesFixtures

    @invalid_attrs %{name: nil, chip_count: nil, hands_played: nil, hands_won: nil}

    test "list_players/0 returns all players" do
      player = player_fixture()
      assert Tables.list_players() == [player]
    end

    test "get_player!/1 returns the player with given id" do
      player = player_fixture()
      assert Tables.get_player!(player.id) == player
    end

    test "create_player/1 with valid data creates a player" do
      valid_attrs = %{name: "some name", chip_count: 42, hands_played: 42, hands_won: 42}

      assert {:ok, %Player{} = player} = Tables.create_player(valid_attrs)
      assert player.name == "some name"
      assert player.chip_count == 42
      assert player.hands_played == 42
      assert player.hands_won == 42
    end

    test "create_player/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tables.create_player(@invalid_attrs)
    end

    test "update_player/2 with valid data updates the player" do
      player = player_fixture()
      update_attrs = %{name: "some updated name", chip_count: 43, hands_played: 43, hands_won: 43}

      assert {:ok, %Player{} = player} = Tables.update_player(player, update_attrs)
      assert player.name == "some updated name"
      assert player.chip_count == 43
      assert player.hands_played == 43
      assert player.hands_won == 43
    end

    test "update_player/2 with invalid data returns error changeset" do
      player = player_fixture()
      assert {:error, %Ecto.Changeset{}} = Tables.update_player(player, @invalid_attrs)
      assert player == Tables.get_player!(player.id)
    end

    test "delete_player/1 deletes the player" do
      player = player_fixture()
      assert {:ok, %Player{}} = Tables.delete_player(player)
      assert_raise Ecto.NoResultsError, fn -> Tables.get_player!(player.id) end
    end

    test "change_player/1 returns a player changeset" do
      player = player_fixture()
      assert %Ecto.Changeset{} = Tables.change_player(player)
    end
  end
end
