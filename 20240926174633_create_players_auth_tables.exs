defmodule Blackjack.Repo.Migrations.CreatePlayersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:players) do
      add :name, :string, default: "DefaultUsername"
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime
      add :chip_count, :integer, default: 500
      add :hands_played, :integer, default: 0
      add :hands_won, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:players, [:email])

    create table(:players_tokens) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:players_tokens, [:player_id])
    create unique_index(:players_tokens, [:context, :token])
  end
end
