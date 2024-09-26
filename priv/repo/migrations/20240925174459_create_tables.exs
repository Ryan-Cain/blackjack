defmodule Blackjack.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:tables) do
      add :name, :string
      add :table_min, :integer
      add :countdown, :integer
      add :table_color, :string

      timestamps(type: :utc_datetime)
    end
  end
end
