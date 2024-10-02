# lib/my_app/game_room_server.ex
defmodule MyApp.GameRoomServer do
  use GenServer

  alias Blackjack.Logic.GameLogic

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, %{game_id: game_id, players: [%{}, %{}, %{}, %{}, %{}]},
      name: via_tuple(game_id)
    )
  end

  # Public API to add a player when they join the room
  def add_player(game_id, player_state) do
    GenServer.cast(via_tuple(game_id), {:add_player, player_state})
  end

  # Public API to remove a player when they leave the room
  def remove_player(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:remove_player, player_id})
  end

  # Public API to get the current state
  def get_game_state(game_id) do
    shared = GenServer.call(via_tuple(game_id), :get_state)

    # player =
    #   Enum.find(shared.players, fn player -> foundPlayer?(player, player_id) end)

    # %{shared: shared, player: player}
    %{shared: shared}
  end

  def foundPlayer?(player, player_id) do
    map_size(player) > 1 and player.player_id == player_id
  end

  def deal_all_players(game_id) do
    table = GenServer.call(via_tuple(game_id), :get_state)
    players = table.players

    reset_players =
      Enum.map(players, fn player ->
        check_and_deal_player(player)
      end)

    new_table = Map.put(table, :players, reset_players)
    GenServer.cast(via_tuple(game_id), {:update_state, new_table})
    %{shared: new_table}
  end

  def check_and_deal_player(player) do
    if map_size(player) > 0 do
      GameLogic.hit(player, :player)
      |> GameLogic.hit(:player)
      |> GameLogic.hit(:dealer)
      |> GameLogic.hit(:dealer)
    else
      player
    end
  end

  def reset_all_players(game_id) do
    table = GenServer.call(via_tuple(game_id), :get_state)
    players = table.players

    reset_players =
      Enum.map(players, fn player ->
        check_and_reset_player(player)
      end)

    new_table = Map.put(table, :players, reset_players)
    GenServer.cast(via_tuple(game_id), {:update_state, new_table})
    new_table
  end

  def check_and_reset_player(player) do
    if map_size(player) > 0 do
      GameLogic.reset_table(
        player.player_id,
        player.player_name,
        player.table_seat,
        player.table_id
      )
    else
      player
    end
  end

  def initial_game_state(player_id, player_name, table_seat) do
    state = %{
      player_id: player_id,
      player_name: player_name,
      table_seat: table_seat,
      player_bet: 0,
      bet_placed: false,
      player_count: 0,
      player_ace_high_count: 0,
      player_cards: [],
      dealer_count: 0,
      dealer_ace_high_count: 0,
      dealer_cards: [],
      dealer_hidden_card: "",
      dealer_bust: false,
      hand_over: false,
      player_won: false
    }

    state
  end

  def init(state) do
    {:ok, state}
  end

  # def update_game_state(game_id, new_state) do
  #   GenServer.cast(via_tuple(game_id), {:update_state, new_state})
  # end

  def handle_cast({:update_state, new_state}, _state) do
    # Broadcast new state via PubSub
    Phoenix.PubSub.broadcast(
      Blackjack.PubSub,
      "game:#{new_state.game_id}",
      {:game_state_update, new_state}
    )

    {:noreply, new_state}
  end

  # Handle adding a player
  def handle_cast(
        {:add_player, %{table_seat: table_seat, player_id: player_id} = player_state},
        state
      ) do
    players = Map.get(state, :players, [])
    has_map_with_value = Enum.any?(players, fn map -> map[:player_id] == player_id end)
    seat_taken = Enum.any?(players, fn map -> map[:table_seat] == table_seat end)

    if has_map_with_value or seat_taken do
      {:noreply, state}
    else
      new_state =
        Map.put(
          state,
          :players,
          List.replace_at(players, table_seat - 1, player_state)
        )

      Phoenix.PubSub.broadcast(
        Blackjack.PubSub,
        "game:#{new_state.game_id}",
        {:game_state_update, new_state}
      )

      {:noreply, new_state}
    end
  end

  # Handle removing a player
  def handle_cast({:remove_player, player_id}, state) do
    players = Map.get(state, :players, [])
    position = Enum.find_index(players, fn player -> Map.get(player, :player_id) == player_id end)
    IO.inspect(position, label: "position")
    new_players = List.replace_at(players, position, %{})
    IO.inspect(new_players, label: "new state")
    new_state = Map.put(state, :players, new_players)
    IO.inspect(new_players, label: "new players")
    IO.inspect(new_state)

    Phoenix.PubSub.broadcast(
      Blackjack.PubSub,
      "game:#{new_state.game_id}",
      {:game_state_update, new_state}
    )

    if Enum.all?(new_players, fn player -> player == %{} end) do
      IO.inspect("no players remain, shutting down gen server")
      # Stop the GenServer if no players remain

      {:stop, :normal, new_state}
    else
      {:noreply, new_state}
    end
  end

  # Return the current state
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Helper function for dynamic naming of GenServers
  defp via_tuple(game_id), do: {:via, Registry, {MyApp.GameRegistry, game_id}}
end
