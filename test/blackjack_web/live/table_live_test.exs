defmodule BlackjackWeb.TableLiveTest do
  use BlackjackWeb.ConnCase

  import Phoenix.LiveViewTest
  import Blackjack.GamesFixtures

  @create_attrs %{
    name: "some name",
    table_min: 42,
    countdown: 42,
    table_color: "some table_color"
  }
  @update_attrs %{
    name: "some updated name",
    table_min: 43,
    countdown: 43,
    table_color: "some updated table_color"
  }
  @invalid_attrs %{name: nil, table_min: nil, countdown: nil, table_color: nil}

  defp create_table(_) do
    table = table_fixture()
    %{table: table}
  end

  describe "Index" do
    setup [:create_table]

    test "lists all tables", %{conn: conn, table: table} do
      {:ok, _index_live, html} = live(conn, ~p"/tables")

      assert html =~ "Listing Tables"
      assert html =~ table.name
    end

    test "saves new table", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/tables")

      assert index_live |> element("a", "New Table") |> render_click() =~
               "New Table"

      assert_patch(index_live, ~p"/tables/new")

      assert index_live
             |> form("#table-form", table: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#table-form", table: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/tables")

      html = render(index_live)
      assert html =~ "Table created successfully"
      assert html =~ "some name"
    end

    test "updates table in listing", %{conn: conn, table: table} do
      {:ok, index_live, _html} = live(conn, ~p"/tables")

      assert index_live |> element("#tables-#{table.id} a", "Edit") |> render_click() =~
               "Edit Table"

      assert_patch(index_live, ~p"/tables/#{table}/edit")

      assert index_live
             |> form("#table-form", table: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#table-form", table: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/tables")

      html = render(index_live)
      assert html =~ "Table updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes table in listing", %{conn: conn, table: table} do
      {:ok, index_live, _html} = live(conn, ~p"/tables")

      assert index_live |> element("#tables-#{table.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#tables-#{table.id}")
    end
  end

  describe "Show" do
    setup [:create_table]

    test "displays table", %{conn: conn, table: table} do
      {:ok, _show_live, html} = live(conn, ~p"/tables/#{table}")

      assert html =~ "Show Table"
      assert html =~ table.name
    end

    test "updates table within modal", %{conn: conn, table: table} do
      {:ok, show_live, _html} = live(conn, ~p"/tables/#{table}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Table"

      assert_patch(show_live, ~p"/tables/#{table}/show/edit")

      assert show_live
             |> form("#table-form", table: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#table-form", table: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/tables/#{table}")

      html = render(show_live)
      assert html =~ "Table updated successfully"
      assert html =~ "some updated name"
    end
  end
end
