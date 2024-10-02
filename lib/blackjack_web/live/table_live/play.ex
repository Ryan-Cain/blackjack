defmodule BlackjackWeb.TableLive.Play do
  use BlackjackWeb, :live_view

  alias Blackjack.Games
  # alias Blackjack.Tables
  alias Blackjack.Accounts
  alias Blackjack.Logic.GameLogic

  @impl true
  def mount(%{"id" => game_id}, _session, %{assigns: %{current_player: current_player}} = socket) do
    IO.inspect("MOUNT")
    player_id = current_player.id
    # initial_state = GameLogic.reset_table(player_id)
    # IO.inspect(initial_state, label: "initial game state is")
    # IO.inspect(socket.assigns, label: "This is the MOUNT socket.assigns")
    # Start the game room GenServer if it doesn't exist
    {game_id_int, _} = Integer.parse(game_id)

    if connected?(socket) do
      IO.inspect("MOUNT: connected")
      Phoenix.PubSub.subscribe(Blackjack.PubSub, "game:#{game_id}")

      unless game_room_exists?(game_id_int) do
        IO.inspect("MOUNT: game room: #{game_id_int} does not exist")
        MyApp.GameRoomSupervisor.start_game_room(game_id_int)
      end
    end

    # Add the player to the game room
    # MyApp.GameRoomServer.add_player(game_id, initial_state)

    # Fetch the current game state
    # game_state = MyApp.GameRoomServer.get_game_state(game_id_int)
    game_state = MyApp.GameRoomServer.get_game_state(game_id_int)
    IO.inspect(game_state, label: "MOUNT: shared game state")

    players = game_state.shared.players
    player_at_table = Enum.any?(players, fn map -> map[:player_id] == player_id end)
    IO.inspect(player_at_table, label: "player at table")

    {:ok,
     assign(socket,
       game_state: %{
         player_id: 0,
         table_seat: 0,
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
       },
       shared_game_state: game_state.shared,
       game_id: game_id,
       sitting_at_table: player_at_table
       #  player_id: player_id
     )}
  end

  #   {:ok, assign(socket, game_state: initial_state)}
  # end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    player_at_table = socket.assigns.sitting_at_table
    IO.inspect(socket, label: "HANDLE PARAMS: socket")

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:sitting_at_table, player_at_table)
     |> assign(:table, Games.get_table!(id))}

    #  |> assign(:players, Tables.get_player!(socket.assigns.current_player.id))}
  end

  @impl true
  def handle_event(
        "sit_at_table",
        %{"seat" => seat},
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    IO.inspect("EVENT: sit_at_table")
    {seat_position, _} = Integer.parse(seat)
    # game_id = 1
    initial_state =
      GameLogic.reset_table(current_player.id, current_player.name, seat_position, table.id)

    IO.inspect(initial_state, label: "initial game state is")

    # Add the player to the game room
    MyApp.GameRoomServer.add_player(table.id, initial_state)

    # Fetch the current game state
    game_state = MyApp.GameRoomServer.get_game_state(table.id)
    IO.inspect(game_state, label: "SIT AT TABLE: shared game state")

    {:noreply,
     assign(socket,
       game_state: initial_state,
       shared_game_state: game_state.shared,
       game_id: table.id,
       sitting_at_table: true
     )}
  end

  # Remove the player from the game room
  def handle_event(
        "get_up_from_table",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    IO.inspect("EVENT: get_up_from_table")
    IO.inspect(table.id, label: "table id")
    IO.inspect(current_player.id, label: "current_player id")
    MyApp.GameRoomServer.remove_player(table.id, current_player.id)
    {:noreply, redirect(socket, to: "/tables")}
  end

  def handle_event(
        "get_up_from_seat",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    IO.inspect("EVENT: get_up_from_table")
    IO.inspect(table.id, label: "table id")
    IO.inspect(current_player.id, label: "current_player id")
    MyApp.GameRoomServer.remove_player(table.id, current_player.id)
    game_state = MyApp.GameRoomServer.get_game_state(table.id)
    IO.inspect(game_state, label: "SIT AT TABLE: shared game state")

    {:noreply,
     assign(socket,
       #  game_state: initial_state,
       shared_game_state: game_state.shared,
       game_id: table.id,
       sitting_at_table: false
     )}
  end

  def handle_event(
        "new-game",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    # {seat_position, _} = Integer.parse(seat)
    reset_players = MyApp.GameRoomServer.reset_all_players(table.id)
    IO.inspect(reset_players, label: "NEW GAME: reset players")
    # initial_state = GameLogic.reset_table(current_player.id, current_player.name, ,  table.id)

    socket =
      assign(socket,
        # game_state: initial_state,
        sitting_at_table: true
      )

    {:noreply, socket}
  end

  def handle_event(
        "deal-cards",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    # {seat_position, _} = Integer.parse(seat)
    dealt_players = MyApp.GameRoomServer.deal_all_players(table.id)

    # filtered_players =
    #   Enum.filter(dealt_players.shared.players, fn player -> map_size(player) > 0 end)

    # player = Enum.find(filtered_players, fn player -> player.player_id == current_player.id end)

    IO.inspect(dealt_players, label: "NEW GAME: reset players")
    # initial_state = GameLogic.reset_table(current_player.id, current_player.name, table.id)

    socket =
      assign(socket,
        # game_state: player,
        sitting_at_table: true,
        shared_game_state: dealt_players.shared
      )

    {:noreply, socket}
  end

  def handle_event("hit-me", _, socket) do
    game_state = socket.assigns.game_state
    game_state_after_hit = GameLogic.hit(game_state, :player)

    if game_state_after_hit.hand_over and game_state_after_hit.player_won do
      new_chip_count = game_state_after_hit.player_bet * 2
      Accounts.update_player(socket.assigns.players, %{chip_count: new_chip_count})
    end

    socket = assign(socket, game_state: game_state_after_hit, sitting_at_table: true)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event(
        "stand",
        _,
        # %{assigns: %{current_player: player, game_state: game_state}} = socket
        socket
      ) do
    # user_id = players.id
    IO.inspect(socket, label: "Stand socket is ")
    %{current_player: player, game_state: game_state} = socket.assigns
    IO.inspect(player, label: "player")
    IO.inspect(game_state, label: "game state")
    game_state_after_hit = GameLogic.player_stands(game_state)
    player_chip_count = player.chip_count
    IO.inspect(player_chip_count, label: "player chip count")
    account = Accounts.update_player(player, %{chip_count: 1200})
    IO.inspect(account, label: "account is ")

    {:ok, updated_player} =
      if game_state_after_hit.hand_over and game_state_after_hit.player_won do
        new_chip_count = game_state.player_bet + player_chip_count
        IO.inspect("this fired")
        IO.inspect(new_chip_count)
        Accounts.update_player(player, %{chip_count: new_chip_count})
      else
        IO.inspect("use original player")
        {:ok, player}
      end

    # why does this have to refresh to show true chip value including winnings???
    IO.inspect("socket returned from Stand")
    IO.inspect(socket.assigns)
    # |> assign(:players, Tables.get_player!(user_id))

    {:noreply,
     socket
     |> assign(game_state: game_state_after_hit)
     |> assign(:sitting_at_table, true)
     |> assign(:current_player, updated_player)}
  end

  def handle_event("add-to-bet", %{"chips" => chips}, socket) do
    IO.inspect(chips)
    {chip_value, _} = Integer.parse(chips)
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, game_state.player_bet + chip_value)
    socket = assign(socket, game_state: new_game_state, sitting_at_table: true)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("all-in", _, socket) do
    player_chips = socket.assigns.current_player.chip_count
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, player_chips)
    socket = assign(socket, game_state: new_game_state, sitting_at_table: true)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("remove-from-bet", %{"chips" => chips}, socket) do
    IO.inspect(chips)
    chips_parse = Integer.parse(chips)
    chip_value = elem(chips_parse, 0)
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, game_state.player_bet - chip_value)
    socket = assign(socket, game_state: new_game_state, sitting_at_table: true)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("clear-bet", _, socket) do
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, 0)
    socket = assign(socket, game_state: new_game_state, sitting_at_table: true)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("place-bet", _, socket) do
    game_state = socket.assigns.game_state
    game_state_placed_bet = Map.put(game_state, :bet_placed, true)
    game_state_initial_deal = GameLogic.initial_deal(game_state_placed_bet)
    socket = assign(socket, game_state: game_state_initial_deal, sitting_at_table: true)
    IO.inspect(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:game_state_update, new_state},
        %{assigns: %{current_player: current_player}} = socket
      ) do
    # Handle game state updates broadcasted via PubSub
    IO.inspect(new_state, label: "Handle info fired!")

    filtered_players =
      Enum.filter(new_state.players, fn player -> map_size(player) > 0 end)

    player = Enum.find(filtered_players, fn player -> player.player_id == current_player.id end)

    # {:noreply, assign(socket, shared_game_state: new_state, game_state: player)}
    {:noreply, assign(socket, shared_game_state: new_state, game_state: player)}
  end

  # NEED THIS BELOW? HAVE THE SAME FUNCTIONALITIY IN REMOVE PLAYER
  # @impl true
  # # Handle the user leaving the room
  # def terminate(_reason, socket) do
  #   game_id = socket.assigns.table.id
  #   player_id = socket.assigns.current_player.id
  #   IO.inspect(socket, label: "socket in terminate")

  #   # Remove the player from the game room
  #   MyApp.GameRoomServer.remove_player(game_id, player_id)
  # end

  defp game_room_exists?(game_id) do
    case Registry.lookup(MyApp.GameRegistry, game_id) do
      [] -> false
      _ -> true
    end
  end

  defp page_title(:play), do: "Play Table"
  defp page_title(:show), do: "Show Table"
  defp page_title(:edit), do: "Edit Table"
end
