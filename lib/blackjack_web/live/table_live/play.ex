defmodule BlackjackWeb.TableLive.Play do
  use BlackjackWeb, :live_view

  alias MyApp.GameRoomServer
  alias Blackjack.Games

  @impl true
  def mount(
        %{"id" => game_id},
        _session,
        socket
      ) do
    {game_id_int, _} = Integer.parse(game_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blackjack.PubSub, "game:#{game_id}")

      unless game_room_exists?(game_id_int) do
        MyApp.GameRoomSupervisor.start_game_room(game_id_int)
      end
    end

    game_state = MyApp.GameRoomServer.get_game_state(game_id_int)

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
         hand_over: false,
         player_won: false,
         active_move: false
       },
       shared_game_state: game_state,
       game_id: game_id
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:table, Games.get_table!(id))}
  end

  @impl true
  def handle_event(
        "sit_at_table",
        %{"seat" => seat},
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    {seat_position, _} = Integer.parse(seat)
    player_info = %{current_player: current_player, seat_position: seat_position}
    MyApp.GameRoomServer.add_player(table, player_info)
    {:noreply, socket}
  end

  # Remove the player from the game room
  def handle_event(
        "get_up_from_table",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    MyApp.GameRoomServer.remove_player(table.id, current_player.id)
    {:noreply, redirect(socket, to: "/tables")}
  end

  def handle_event(
        "get_up_from_seat",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    MyApp.GameRoomServer.remove_player(table.id, current_player.id)
    {:noreply, socket}
  end

  def handle_event(
        "show-state",
        _,
        %{assigns: %{table: table}} = socket
      ) do
    MyApp.GameRoomServer.show_state(table.id)
    {:noreply, socket}
  end

  def handle_event(
        "get_some_more_chips",
        _,
        %{assigns: %{current_player: current_player}} = socket
      ) do
    MyApp.GameRoomServer.get_more_chips(current_player.id)
    {:noreply, socket}
  end

  def handle_event(
        "hit-me",
        _,
        %{assigns: %{current_player: current_player, table: table}} =
          socket
      ) do
    GameRoomServer.player_hit(table.id, current_player.id)

    {:noreply, socket}
  end

  def handle_event(
        "stand",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    MyApp.GameRoomServer.player_stands(table.id, current_player.id)

    {:noreply, socket}
  end

  def handle_event(
        "add-to-bet",
        %{"chips" => chips},
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    {chip_value, _} = Integer.parse(chips)
    MyApp.GameRoomServer.adjust_bet(current_player.id, table.id, :add, chip_value)
    {:noreply, socket}
  end

  def handle_event(
        "remove-from-bet",
        %{"chips" => chips},
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    {chip_value, _} = Integer.parse(chips)
    MyApp.GameRoomServer.adjust_bet(current_player.id, table.id, :sub, chip_value)
    {:noreply, socket}
  end

  def handle_event(
        "all-in",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    MyApp.GameRoomServer.player_all_in(current_player.id, table.id)
    {:noreply, socket}
  end

  def handle_event(
        "clear-bet",
        _,
        %{assigns: %{current_player: current_player, table: table}} = socket
      ) do
    MyApp.GameRoomServer.clear_bet(current_player.id, table.id)
    {:noreply, socket}
  end

  def handle_event(
        "place-bet",
        _,
        %{assigns: %{current_player: current_player, game_state: game_state, table: table}} =
          socket
      ) do
    GameRoomServer.place_bet(table.id, current_player.id, game_state.player_bet)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:game_state_update, new_state},
        %{assigns: %{current_player: current_player}} = socket
      ) do
    filtered_players =
      Enum.filter(new_state.players, fn player -> map_size(player) > 0 end)

    player = Enum.find(filtered_players, fn player -> player.player_id == current_player.id end)

    player =
      if player do
        player
      else
        %{
          player_id: 0,
          player_name: "",
          active_move: false,
          table_seat: 0,
          player_bet: 0,
          bet_placed: false,
          player_count: 0,
          player_ace_high_count: 0,
          player_cards: [],
          hand_over: false,
          player_won: false,
          player_bust: false,
          player_stands: false
        }
      end

    {:noreply, assign(socket, shared_game_state: new_state, game_state: player)}
  end

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
