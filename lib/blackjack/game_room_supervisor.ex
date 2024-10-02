# lib/my_app/game_room_supervisor.ex
defmodule MyApp.GameRoomSupervisor do
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Public function to start a game room if it doesn't exist
  def start_game_room(game_id) do
    IO.inspect("GAME ROOM SUPERVISOR: start_game_room with game_id:#{game_id}")
    child_spec = {MyApp.GameRoomServer, game_id}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
