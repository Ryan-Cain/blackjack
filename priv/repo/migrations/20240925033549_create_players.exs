defmodule Blackjack.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :name, :string
      add :chip_count, :integer
      add :hands_played, :integer
      add :hands_won, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
