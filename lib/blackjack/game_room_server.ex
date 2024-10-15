# lib/my_app/game_room_server.ex
defmodule MyApp.GameRoomServer do
  use GenServer

  alias Blackjack.Accounts
  alias Blackjack.Accounts.Player
  alias Blackjack.Games
  alias Blackjack.Logic.GameLogic

  # kicking off game room gen server
  def start_link(game_id) do
    GenServer.start_link(
      __MODULE__,
      %{
        game_id: game_id,
        game_flow: %{
          first_game: true,
          phase: "reset",
          active_seat: 1,
          countdown: 0,
          timer_total: 0,
          timer_amount: 0
        },
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

  def game_flow(%{game_flow: %{phase: phase}}) do
    case phase do
      "reset" -> GenServer.cast(self(), :reset_phase)
      "bet" -> GenServer.cast(self(), :bet_phase)
      "deal" -> GenServer.cast(self(), :deal_phase)
      "play" -> GenServer.cast(self(), :play_phase)
      "final" -> GenServer.cast(self(), :final_phase)
      "pause" -> IO.inspect("paused")
    end
  end

  def add_player(table, player_info) do
    GenServer.cast(via_tuple(table.id), {:add_player, %{player_info: player_info, table: table}})
  end

  def remove_player(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:remove_player, player_id})
  end

  def player_hit(table_id, player_id) do
    GenServer.cast(via_tuple(table_id), {:player_hit, %{player_id: player_id}})
  end

  def player_stands(table_id, player_id) do
    GenServer.cast(via_tuple(table_id), {:player_stands, %{player_id: player_id}})
  end

  def get_game_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
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

  def player_all_in(player_id, table_id) do
    player = Accounts.get_player!(player_id)
    IO.inspect(player, label: "player all in")
    bet = %{player_id: player_id, player_bet: player.chip_count}
    GenServer.cast(via_tuple(table_id), {:change_bet_value, bet})
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
    IO.inspect("init()")
    table = Games.get_table!(state.game_id)
    game_flow_add_count_down = Map.put(state.game_flow, :countdown, table.countdown)
    game_flow_add_timer_amount = Map.put(game_flow_add_count_down, :timer_total, table.countdown)
    new_game_state = Map.put(state, :game_flow, game_flow_add_timer_amount)
    {:ok, new_game_state}
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
        {:add_player,
         %{player_info: %{seat_position: seat, current_player: current_player}, table: table}},
        state
      ) do
    IO.inspect("handle_cast() _ :add_player")

    player =
      GameLogic.initial_player_state(current_player.id, current_player.name, seat)

    players = Map.get(state, :players)
    has_map_with_value = Enum.any?(players, fn map -> map[:player_id] == current_player.id end)
    seat_taken = Enum.any?(players, fn map -> map[:table_seat] == seat end)

    add_time =
      put_in(
        state[:game_flow][:timer_total],
        table.countdown
      )

    if has_map_with_value or seat_taken do
      {:noreply, add_time}
    else
      new_state =
        Map.put(
          add_time,
          :players,
          List.replace_at(players, seat - 1, player)
        )

      position = Enum.find_index(players, fn player -> Map.get(player, :player_id) > 0 end)

      if position == nil do
        IO.inspect("start game from add player")
        Process.send_after(self(), :timer_countdown, 2000)
      end

      IO.inspect(position, label: "position")

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

    if Enum.all?(new_players, fn player -> player.player_id == 0 end) do
      IO.inspect("no players remain, shutting down gen server")
      # Stop the GenServer if no players remain

      {:stop, :normal, new_state}
    else
      {:noreply, new_state}
    end
  end

  def handle_cast({:change_bet_value, %{player_id: player_id, player_bet: player_bet}}, state) do
    IO.inspect("handle_cast place bet")

    position =
      Enum.find_index(state.players, fn player -> Map.get(player, :player_id) == player_id end)

    player = Enum.find(state.players, fn player -> player.player_id == player_id end)
    player_w_bet = Map.put(player, :player_bet, player_bet)

    new_players =
      List.replace_at(state.players, position, player_w_bet)

    new_state = Map.put(state, :players, new_players)
    broadcast_to_pubsub(:game_state_update, state.game_id, new_state)
    {:noreply, new_state}
  end

  def handle_cast({:place_bet, %{player_id: player_id, player_bet: player_bet}}, state) do
    IO.inspect("handle_cast place bet")

    position =
      Enum.find_index(state.players, fn player -> Map.get(player, :player_id) == player_id end)

    player = Enum.find(state.players, fn player -> player.player_id == player_id end)
    player_w_bet = Map.put(player, :player_bet, player_bet)
    player_placed_bet = Map.put(player_w_bet, :bet_placed, true)

    new_players =
      List.replace_at(state.players, position, player_placed_bet)

    new_state = Map.put(state, :players, new_players)
    broadcast_to_pubsub(:game_state_update, state.game_id, new_state)
    {:noreply, new_state}
  end

  def handle_cast({:player_hit, %{player_id: player_id}}, state) do
    IO.inspect("handle_cast player_hit")

    position =
      Enum.find_index(state.players, fn player -> Map.get(player, :player_id) == player_id end)

    player = Enum.find(state.players, fn player -> player.player_id == player_id end)
    player_after_hit = GameLogic.hit(player, :player)

    new_players =
      List.replace_at(state.players, position, player_after_hit)

    new_state = Map.put(state, :players, new_players)
    broadcast_to_pubsub(:game_state_update, state.game_id, new_state)
    {:noreply, new_state}
  end

  def handle_cast({:player_stands, %{player_id: player_id}}, state) do
    IO.inspect("handle_cast player_hit")

    position =
      Enum.find_index(state.players, fn player -> Map.get(player, :player_id) == player_id end)

    player = Enum.find(state.players, fn player -> player.player_id == player_id end)
    player_after_stand = GameLogic.player_stands(player)

    new_players =
      List.replace_at(state.players, position, player_after_stand)

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
    IO.inspect("handle_cast() - :bet_phase")

    IO.inspect(game_state.game_flow.active_seat,
      label: "handle_cast() - :bet_phase - game flow active seat"
    )

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
        # Process.send_after(self(), :next_phase, 5000)
        Process.send_after(self(), :timer_countdown, 1000)
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
              new_game_flow = Map.put(new_game_state.game_flow, :phase, "deal")
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
          new_game_flow = Map.put(new_game_state.game_flow, :phase, "deal")
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
    IO.inspect("handle_cast() - :play_phase")

    IO.inspect(game_state.game_flow.active_seat,
      label: "handle_cast() - :play_phase - game flow active seat"
    )

    if isPlayer?(chair) do
      IO.inspect("play phase - found active player")

      if not chair.active_move do
        IO.inspect("play phase - player not active move")
        new_chair = Map.put(chair, :active_move, true)

        new_players =
          List.replace_at(game_state.players, game_state.game_flow.active_seat - 1, new_chair)

        new_game_state =
          Map.put(game_state, :players, new_players)

        IO.inspect(new_game_state, label: "play phase - player not active move new game state")
        # Process.send_after(self(), :next_phase, 5000)
        Process.send_after(self(), :timer_countdown, 100)
        broadcast_to_pubsub(:game_state_update, game_state.game_id, new_game_state)
        {:noreply, new_game_state}
      else
        IO.inspect("play phase - player has active move")

        if chair.player_bet == 0 do
          IO.inspect("play phase - kicking player out of seat")
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
              new_game_flow = Map.put(new_game_state.game_flow, :phase, "final")
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
      IO.inspect("play phase - increment one active player")

      new_game_state =
        put_in(game_state[:game_flow][:active_seat], game_state.game_flow.active_seat + 1)

      check_for_last_seat =
        if game_state.game_flow.active_seat == 5 do
          new_game_flow = Map.put(new_game_state.game_flow, :phase, "final")
          new_active_seat = Map.put(new_game_flow, :active_seat, 1)
          Map.put(new_game_state, :game_flow, new_active_seat)
        else
          new_game_state
        end

      Process.send_after(self(), :next_phase, 100)
      {:noreply, check_for_last_seat}
    end
  end

  def handle_cast(:deal_phase, table) do
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
    table_update_phase = put_in(table_w_dealer[:game_flow][:phase], "play")

    broadcast_to_pubsub(:game_state_update, table.game_id, table_update_phase)
    Process.send_after(self(), :next_phase, 100)

    {:noreply, table_update_phase}
  end

  def handle_cast(:final_phase, table) do
    IO.inspect("final phase!!!")
    players = table.players
    table_updated_phase = Map.put(table.game_flow, :phase, "reset")

    squared_up_players =
      Enum.map(players, fn player ->
        square_up_player(player, table.dealer)
      end)

    add_players = Map.put(table, :players, squared_up_players)
    add_phase = Map.put(add_players, :game_flow, table_updated_phase)

    broadcast_to_pubsub(:game_state_update, table.game_id, add_phase)
    Process.send_after(self(), :next_phase, 100)
    {:noreply, add_phase}
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
    broadcast_to_pubsub(:game_state_update, table.game_id, add_phase)
    Process.send_after(self(), :timer_countdown, 100)
    {:noreply, add_phase}
  end

  def handle_cast(:show_state, state) do
    # Call game_flow or any other process to move to the next phase
    IO.inspect(state, label: "show state")
    {:noreply, state}
  end

  def square_up_player(player, dealer) do
    if player.player_id > 0 do
      IO.inspect(player, label: "square up player")
      player_db = Accounts.get_player!(player.player_id)
      IO.inspect(player_db, label: "square up player")

      if dealer.dealer_bust and not player.player_bust do
        Accounts.update_player(player_db, %{chip_count: player_db.chip_count + player.player_bet})
      else
        if player.player_count > dealer.dealer_count do
          Accounts.update_player(player_db, %{
            chip_count: player_db.chip_count + player.player_bet
          })
        else
          if player.player_count < dealer.dealer_count do
            Accounts.update_player(player_db, %{
              chip_count: player_db.chip_count - player.player_bet
            })
          end
        end
      end
    end

    player
  end

  def check_and_reset_player(player) do
    if player.player_id > 0 do
      GameLogic.initial_player_state(
        player.player_id,
        player.player_name,
        player.table_seat
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

  def handle_info(:timer_countdown, state) do
    curr_player =
      Enum.find(state.players, fn player -> player.table_seat == state.game_flow.active_seat end)

    timer_up =
      if curr_player do
        if curr_player.player_id do
          hand_over_or_bust = curr_player.hand_over or curr_player.player_bust
          bet_phase_timer_up = curr_player.bet_placed and state.game_flow.phase == "bet"
          play_phase_timer_up = hand_over_or_bust and state.game_flow.phase == "play"
          bet_phase_timer_up or play_phase_timer_up
        end
      else
        false
      end

    new_state_reset =
      if state.game_flow.countdown == -1 or timer_up do
        Process.send_after(self(), :next_phase, 100)

        state_reset_countdown = put_in(state[:game_flow][:countdown], state.game_flow.timer_total)
        state_reset_timer_amount = put_in(state_reset_countdown[:game_flow][:timer_amount], 0)
        put_in(state_reset_timer_amount[:game_flow][:first_game], false)
      else
        remainder = div(100, state.game_flow.timer_total)
        mult = remainder * state.game_flow.countdown
        amount = 100 - mult

        IO.inspect(state.game_flow.countdown, label: "countdown")
        IO.inspect(remainder, label: "remainder")
        IO.inspect(mult, label: "mult")
        IO.inspect(amount, label: "amount")
        game_flow = state.game_flow
        game_flow_w_timer = Map.put(game_flow, :timer_amount, amount)

        Process.send_after(self(), :timer_countdown, 1000)
        Map.put(state, :game_flow, game_flow_w_timer)
      end

    broadcast_to_pubsub(:game_state_update, state.game_id, new_state_reset)

    game_flow_w_countdown =
      if state.game_flow.countdown == -1 or timer_up do
        new_state_reset
      else
        game_flow = new_state_reset.game_flow
        new_game_flow = Map.put(game_flow, :countdown, state.game_flow.countdown - 1)
        Map.put(state, :game_flow, new_game_flow)
      end

    {:noreply, game_flow_w_countdown}
  end

  # Return the current state
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def get_more_chips(player_id) do
    player_db = Accounts.get_player!(player_id)
    Accounts.update_player(player_db, %{chip_count: 500})
  end

  def show_state(id) do
    GenServer.cast(via_tuple(id), :show_state)
  end

  defp isPlayer?(player) do
    player.player_id > 0
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
