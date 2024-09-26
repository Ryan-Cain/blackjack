defmodule BlackjackWeb.TableLive.Play do
  use BlackjackWeb, :live_view

  alias Blackjack.Games
  alias Blackjack.Tables
  alias Blackjack.Logic.GameLogic

  @impl true
  def mount(_params, _session, socket) do
    initial_state = GameLogic.reset_table()
    IO.inspect(initial_state)
    {:ok, assign(socket, game_state: initial_state)}
  end

  @impl true
  def handle_params(%{"id" => id, "user_id" => user_id}, _, socket) do
    IO.inspect("user_id")
    IO.inspect(user_id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:table, Games.get_table!(id))
     |> assign(:players, Tables.get_player!(user_id))}
  end

  @impl true
  def handle_event("new-game", _, socket) do
    initial_state = GameLogic.reset_table()
    socket = assign(socket, game_state: initial_state)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("hit-me", _, socket) do
    game_state = socket.assigns.game_state
    game_state_after_hit = GameLogic.hit(game_state, :player)

    if game_state_after_hit.hand_over and game_state_after_hit.player_won do
      new_chip_count = game_state_after_hit.player_bet * 2
      IO.inspect("this fired")
      IO.inspect(new_chip_count)
      # updated_attrs = Map.put(attrs, "attrs", new_chip_count)
      update = Tables.update_player(socket.assigns.players, %{chip_count: new_chip_count})
      IO.inspect(update)
    end

    socket = assign(socket, game_state: game_state_after_hit)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("stand", _, socket) do
    user_id = socket.assigns.players.id
    game_state = socket.assigns.game_state
    game_state_after_hit = GameLogic.player_stands(game_state)
    player_chip_count = socket.assigns.players.chip_count

    player =
      if game_state_after_hit.hand_over and game_state_after_hit.player_won do
        new_chip_count = game_state_after_hit.player_bet + player_chip_count
        IO.inspect("this fired")
        IO.inspect(new_chip_count)
        # updated_attrs = Map.put(attrs, "attrs", new_chip_count)
        Tables.update_player(socket.assigns.players, %{chip_count: new_chip_count})
      else
        {"", ""}
      end

    player_struct = elem(player, 1)
    IO.inspect(player_struct)
    IO.inspect("player struct")

    socket =
      assign(socket, game_state: game_state_after_hit)
      |> assign(:players, Tables.get_player!(user_id))

    # why does this have to refresh to show true chip value including winnings???
    IO.inspect(socket)
    # |> assign(:players, Tables.get_player!(user_id))

    {:noreply, socket}
  end

  def handle_event("add-to-bet", %{"chips" => chips}, socket) do
    IO.inspect(chips)
    chips_parse = Integer.parse(chips)
    chip_value = elem(chips_parse, 0)
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, game_state.player_bet + chip_value)
    socket = assign(socket, game_state: new_game_state)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("all-in", _, socket) do
    player_chips = socket.assigns.players.chip_count
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, player_chips)
    socket = assign(socket, game_state: new_game_state)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("remove-from-bet", %{"chips" => chips}, socket) do
    IO.inspect(chips)
    chips_parse = Integer.parse(chips)
    chip_value = elem(chips_parse, 0)
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, game_state.player_bet - chip_value)
    socket = assign(socket, game_state: new_game_state)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("clear-bet", _, socket) do
    game_state = socket.assigns.game_state
    new_game_state = Map.put(game_state, :player_bet, 0)
    socket = assign(socket, game_state: new_game_state)
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_event("place-bet", _, socket) do
    game_state = socket.assigns.game_state
    game_state_placed_bet = Map.put(game_state, :bet_placed, true)
    game_state_initial_deal = GameLogic.initial_deal(game_state_placed_bet)
    socket = assign(socket, game_state: game_state_initial_deal)
    IO.inspect(socket)
    {:noreply, socket}
  end

  defp page_title(:play), do: "Play Table"
  defp page_title(:show), do: "Show Table"
  defp page_title(:edit), do: "Edit Table"
end
