defmodule Blackjack.GamesTest do
  use Blackjack.DataCase

  alias Blackjack.Games

  describe "tables" do
    alias Blackjack.Games.Table

    import Blackjack.GamesFixtures

    @invalid_attrs %{name: nil, table_min: nil, countdown: nil, table_color: nil}

    test "list_tables/0 returns all tables" do
      table = table_fixture()
      assert Games.list_tables() == [table]
    end

    test "get_table!/1 returns the table with given id" do
      table = table_fixture()
      assert Games.get_table!(table.id) == table
    end

    test "create_table/1 with valid data creates a table" do
      valid_attrs = %{
        name: "some name",
        table_min: 42,
        countdown: 42,
        table_color: "some table_color"
      }

      assert {:ok, %Table{} = table} = Games.create_table(valid_attrs)
      assert table.name == "some name"
      assert table.table_min == 42
      assert table.countdown == 42
      assert table.table_color == "some table_color"
    end

    test "create_table/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_table(@invalid_attrs)
    end

    test "update_table/2 with valid data updates the table" do
      table = table_fixture()

      update_attrs = %{
        name: "some updated name",
        table_min: 43,
        countdown: 43,
        table_color: "some updated table_color"
      }

      assert {:ok, %Table{} = table} = Games.update_table(table, update_attrs)
      assert table.name == "some updated name"
      assert table.table_min == 43
      assert table.countdown == 43
      assert table.table_color == "some updated table_color"
    end

    test "update_table/2 with invalid data returns error changeset" do
      table = table_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_table(table, @invalid_attrs)
      assert table == Games.get_table!(table.id)
    end

    test "delete_table/1 deletes the table" do
      table = table_fixture()
      assert {:ok, %Table{}} = Games.delete_table(table)
      assert_raise Ecto.NoResultsError, fn -> Games.get_table!(table.id) end
    end

    test "change_table/1 returns a table changeset" do
      table = table_fixture()
      assert %Ecto.Changeset{} = Games.change_table(table)
    end
  end
end
