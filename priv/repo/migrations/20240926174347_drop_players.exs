defmodule Blackjack.Repo.Migrations.DropPlayers do
  use Ecto.Migration

  def change do
    drop table("players")
  end
end
