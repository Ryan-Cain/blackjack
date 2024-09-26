defmodule Blackjack.Games.Table do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tables" do
    field :name, :string
    field :table_min, :integer
    field :countdown, :integer
    field :table_color, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(table, attrs) do
    table
    |> cast(attrs, [:name, :table_min, :countdown, :table_color])
    |> validate_required([:name, :table_min, :countdown, :table_color])
  end
end
