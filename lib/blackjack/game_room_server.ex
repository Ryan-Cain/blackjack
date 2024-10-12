# lib/my_app/game_room_server.ex
defmodule MyApp.GameRoomServer do
  use GenServer

  alias Blackjack.Logic.GameLogic

  # kicking off game room gen server
  def start_link(game_id) do
    GenServer.start_link(
      __MODULE__,
      %{
        game_id: game_id,
        game_flow: %{phase: "reset", active_seat: 1},
        dealer: GameLogic.initial_dealer_state(game_id),
        players: [
          %{table_seat: 0, player_id: 0},
          %{table_seat: 0, player_id: 0},
          %{table_seat: 0, player_id: 0},
          %{table_seat: 0, player_id: 0},
          %{table_seat: 0, player_id: 0}
        ]
      },
      name: via_tuple(game_id)
    )
  end

  def start_game(game_id) do
    GenServer.cast(via_tuple(game_id), :start_game)
  end

  def game_flow(game_state) do
    # game_state = GenServer.call(via_tuple(game_id), :get_state)
    # game_id = game_state.game_id
    IO.inspect(game_state, label: "game_flow() game_state")
    phase = game_state.game_flow.phase
    IO.inspect(phase, label: "game_flow() phase")

    case phase do
      "reset" -> GenServer.cast(self(), :reset_phase)
      "bet" -> GenServer.cast(self(), :bet_phase)
      "play" -> GenServer.cast(self(), :play_phase)
    end
  end

  def isPlayer?(player) do
    player.player_id > 0
  end

  # Public API to add a player when they join the room
  def add_player(game_id, player_info) do
    IO.inspect(player_info, label: "add player2")
    GenServer.cast(via_tuple(game_id), {:add_player, player_info})
  end

  # Public API to remove a player when they leave the room
  def remove_player(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:remove_player, player_id})
  end

  # Public API to get the current state
  def get_game_state(game_id) do
    # shared = GenServer.call(via_tuple(game_id), :get_state)

    # player =
    #   Enum.find(shared.players, fn player -> foundPlayer?(player, player_id) end)

    # %{shared: shared, player: player}
    # %{shared: shared}
    GenServer.call(via_tuple(game_id), :get_state)
  end

  def foundPlayer?(player, player_id) do
    map_size(player) > 1 and player.player_id == player_id
  end

  def deal_all_players(game_id) do
    table = GenServer.call(via_tuple(game_id), :get_state)
    players = table.players

    dealer =
      GameLogic.hit(table.dealer, :dealer)
      |> GameLogic.hit(:dealer)

    reset_players =
      Enum.map(players, fn player ->
        check_and_deal_player(player)
      end)

    new_table = Map.put(table, :players, reset_players)
    table_w_dealer = Map.put(new_table, :dealer, dealer)
    GenServer.cast(self(), {:update_state_broadcast, table_w_dealer})
    %{shared: table_w_dealer}
  end

  def check_and_deal_player(player) do
    if player.table_seat > 0 do
      GameLogic.hit(player, :player)
      |> GameLogic.hit(:player)
    else
      player
    end
  end

  def place_bet(game_id, player_id, player_bet) do
    bet = %{player_id: player_id, player_bet: player_bet}
    GenServer.cast(via_tuple(game_id), {:place_bet, bet})
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

  def remove_hidden_dealer_card(state) do
    removed_hidden =
      Map.update!(state, :dealer, fn dealer_state ->
        Map.delete(dealer_state, :hidden_card)
      end)

    removed_hidden
  end

  # Handle adding a player
  def handle_cast(
        {:add_player, %{seat_position: seat, current_player: current_player}},
        state
      ) do
    player =
      GameLogic.initial_player_state(current_player.id, current_player.name, seat, state.game_id)

    players = Map.get(state, :players, [])
    has_map_with_value = Enum.any?(players, fn map -> map[:player_id] == current_player.id end)
    seat_taken = Enum.any?(players, fn map -> map[:table_seat] == seat end)

    if has_map_with_value or seat_taken do
      {:noreply, state}
    else
      new_state =
        Map.put(
          state,
          :players,
          List.replace_at(players, seat - 1, player)
        )

      broadcast_to_pubsub(:game_state_update, new_state.game_id, new_state)

      {:noreply, new_state}
    end
  end

  # Handle removing a player
  def handle_cast({:remove_player, player_id}, state) do
    players = Map.get(state, :players, [])
    position = Enum.find_index(players, fn player -> Map.get(player, :player_id) == player_id end)
    IO.inspect(position, label: "position")
    new_players = List.replace_at(players, position, %{table_seat: 0, player_id: 0})
    IO.inspect(new_players, label: "new state")
    new_state = Map.put(state, :players, new_players)
    IO.inspect(new_players, label: "new players")
    IO.inspect(new_state)

    broadcast_to_pubsub(:game_state_update, new_state.game_id, new_state)

    if Enum.all?(new_players, fn player -> player == %{} end) do
      IO.inspect("no players remain, shutting down gen server")
      # Stop the GenServer if no players remain

      {:stop, :normal, new_state}
    else
      {:noreply, new_state}
    end
  end

  
  def handle_cast({:timer_up, game_id}, state) do
    # Call game_flow or any other process to move to the next phase
    # game_flow(state.game_id)
    IO.inspect(state, label: "state in timer up ")
    IO.inspect(game_id)
    Process.send_after(self(), :timer_up_action, 5000)
    {:noreply, state}
  end

  def handle_cast({:place_bet, %{player_id: player_id, player_bet: player_bet}}, state) do
    IO.inspect("handle_cast place bet")
    IO.inspect(player_id)
    IO.inspect(player_bet)
    # players = state.players
    position =
      Enum.find_index(state.players, fn player -> Map.get(player, :player_id) == player_id end)

    player = Enum.find(state.players, fn player -> player.player_id == player_id end)
    player_w_bet = Map.put(player, :player_bet, player_bet)

    new_players =
      List.replace_at(state.players, position, player_w_bet)

    IO.inspect(new_players, label: "new state")
    new_state = Map.put(state, :players, new_players)
    broadcast_to_pubsub(:game_state_update, state.game_id, new_state)
    {:noreply, new_state}
  end

  def handle_cast(:start_game, state) do
    # Call game_flow or any other process to move to the next phase
    game_flow(state)
    {:noreply, state}
  end

  def handle_cast(:bet_phase, game_state) do
    chair = Enum.at(game_state.players, game_state.game_flow.active_seat - 1)
    IO.inspect(game_state.game_flow.active_seat, label: "game flow active seat")

    if isPlayer?(chair) do
      IO.inspect("found active player")

      if not chair.active_move do
        IO.inspect("player not active move")
        new_chair = Map.put(chair, :active_move, true)

        new_players =
          List.replace_at(game_state.players, game_state.game_flow.active_seat - 1, new_chair)

        new_game_state =
          Map.put(game_state, :players, new_players)

        IO.inspect(new_game_state, label: "player not active move new game state")
        Process.send_after(self(), :next_phase, 5000)
        broadcast_to_pubsub(:game_state_update, game_state.game_id, new_game_state)
        {:noreply, new_game_state}
      else
        IO.inspect("player has active move")

        if chair.player_bet == 0 do
          IO.inspect("kicking player out of seat")
          # kick player out of seat, you have to bet to play!!
          new_players =
            List.replace_at(game_state.players, game_state.game_flow.active_seat - 1, %{
              table_seat: 0,
              player_id: 0
            })

          new_game_state =
            Map.put(game_state, :players, new_players)

          new_game_state_move_seat =
            put_in(
              new_game_state[:game_flow][:active_seat],
              new_game_state.game_flow.active_seat + 1
            )

          Process.send_after(self(), :next_phase, 100)
          broadcast_to_pubsub(:game_state_update, game_state.game_id, new_game_state_move_seat)
          {:noreply, new_game_state_move_seat}
        else
          new_chair = Map.put(chair, :active_move, false)

          new_players =
            List.replace_at(game_state.players, game_state.game_flow.active_seat - 1, new_chair)

          new_game_state =
            Map.put(game_state, :players, new_players)

          new_game_state_move_seat =
            put_in(
              new_game_state[:game_flow][:active_seat],
              new_game_state.game_flow.active_seat + 1
            )

          check_for_last_seat =
            if game_state.game_flow.active_seat == 5 do
              new_game_flow = Map.put(new_game_state.game_flow, :phase, "play")
              new_active_seat = Map.put(new_game_flow, :active_seat, 1)
              Map.put(new_game_state, :game_flow, new_active_seat)
            else
              new_game_state_move_seat
            end

          Process.send_after(self(), :next_phase, 100)
          broadcast_to_pubsub(:game_state_update, game_state.game_id, new_game_state_move_seat)
          {:noreply, check_for_last_seat}
        end
      end
    else
      IO.inspect("increment one active player")

      new_game_state =
        put_in(game_state[:game_flow][:active_seat], game_state.game_flow.active_seat + 1)

      check_for_last_seat =
        if game_state.game_flow.active_seat == 5 do
          new_game_flow = Map.put(new_game_state.game_flow, :phase, "play")
          new_active_seat = Map.put(new_game_flow, :active_seat, 1)
          Map.put(new_game_state, :game_flow, new_active_seat)
        else
          new_game_state
        end

      Process.send_after(self(), :next_phase, 100)
      {:noreply, check_for_last_seat}
    end
  end

  def handle_cast(:play_phase, game_state) do
    chair = Enum.at(game_state.players, game_state.game_flow.active_seat - 1)
    IO.inspect(game_state.game_flow.active_seat, label: "game flow active seat")

    if isPlayer?(chair) do
      IO.inspect("found active player")

      if not chair.active_move do
        IO.inspect("player not active move")
        new_chair = Map.put(chair, :active_move, true)

        new_players =
          List.replace_at(game_state.players, game_state.game_flow.active_seat - 1, new_chair)

        new_game_state =
          Map.put(game_state, :players, new_players)

        IO.inspect(new_game_state, label: "player not active move new game state")
        Process.send_after(self(), :next_phase, 5000)
        {:noreply, new_game_state}
      else
        IO.inspect("player has active move")

        if chair.player_bet == 0 do
          IO.inspect("kicking player out of seat")
          # kick player out of seat, you have to bet to play!!
          new_players =
            List.replace_at(game_state.players, game_state.game_flow.active_seat - 1, %{
              table_seat: 0,
              player_id: 0
            })

          new_game_state =
            Map.put(game_state, :players, new_players)

          new_game_state_move_seat =
            put_in(
              new_game_state[:game_flow][:active_seat],
              new_game_state.game_flow.active_seat + 1
            )

          broadcast_to_pubsub(:game_state_update, game_state.game_id, new_game_state_move_seat)
          {:noreply, new_game_state_move_seat}
        else
          new_chair = Map.put(chair, :active_move, false)

          new_players =
            List.replace_at(game_state.players, game_state.game_flow.active_seat - 1, new_chair)

          new_game_state =
            Map.put(game_state, :players, new_players)

          new_game_state_move_seat =
            put_in(
              new_game_state[:game_flow][:active_seat],
              new_game_state.game_flow.active_seat + 1
            )

          Process.send_after(self(), :next_phase, 100)
          {:noreply, new_game_state_move_seat}
        end
      end
    else
      IO.inspect("increment one active player")

      new_game_state =
        put_in(game_state[:game_flow][:active_seat], game_state.game_flow.active_seat + 1)

      check_for_last_seat =
        if game_state.game_flow.active_seat == 5 do
          new_game_flow = Map.put(new_game_state.game_flow, :phase, "play")
          new_active_seat = Map.put(new_game_flow, :active_seat, 1)
          Map.put(new_game_state, :game_flow, new_active_seat)
        else
          new_game_state
        end

      Process.send_after(self(), :next_phase, 100)
      {:noreply, check_for_last_seat}
    end
  end

  def handle_cast(:reset_phase, table) do
    players = table.players
    table_updated_phase = Map.put(table.game_flow, :phase, "bet")

    reset_players =
      Enum.map(players, fn player ->
        check_and_reset_player(player)
      end)

    reset_dealer = GameLogic.initial_dealer_state(table.game_id)
    add_dealer = Map.put(table, :dealer, reset_dealer)
    add_players = Map.put(add_dealer, :players, reset_players)
    add_phase = Map.put(add_players, :game_flow, table_updated_phase)
    # removed_hidden_card = remove_hidden_dealer_card(new_table)
    # GenServer.cast(self(), {:update_state_no_broadcast, removed_hidden_card})
    broadcast_to_pubsub(:game_state_update, table.game_id, add_phase)
    {:noreply, add_phase}
  end

  def check_and_reset_player(player) do
    if player.table_seat > 0 do
      GameLogic.initial_player_state(
        player.player_id,
        player.player_name,
        player.table_seat,
        0
      )
    else
      player
    end
  end

  # Handle the delayed message in GenServer
  def handle_info(:next_phase, state) do
    # Call game_flow or any other process to move to the next phase
    game_flow(state)
    {:noreply, state}
  end

  # Return the current state
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp broadcast_to_pubsub(message, game_id, state) do
    Phoenix.PubSub.broadcast(
      Blackjack.PubSub,
      "game:#{game_id}",
      {message, state}
    )
  end

  # Helper function for dynamic naming of GenServers
  defp via_tuple(game_id), do: {:via, Registry, {MyApp.GameRegistry, game_id}}
end
