defmodule Blackjack.Tables.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :name, :string
    field :chip_count, :integer
    field :hands_played, :integer
    field :hands_won, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :chip_count, :hands_played, :hands_won])
    |> validate_required([:name, :chip_count, :hands_played, :hands_won])
  end
end
