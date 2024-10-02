defmodule Blackjack.Logic.GameLogic do
  def initial_game_state(player_id, player_name, table_seat, table_id) do
    state = %{
      player_id: player_id,
      player_name: player_name,
      table_id: 0,
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

  def hit(game_state, :player) do
    # Create Lists for random card and generate it
    suits = ["H", "S", "D", "C"]
    face = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    card_face = Enum.random(face)
    card_suits = Enum.random(suits)
    card_full = card_face <> "-" <> card_suits
    # Get players current count
    player_count = Map.get(game_state, :player_count)
    # Get point value of face card, and whether or not its ace high (Ex. if "A" [10, true])
    face_value = get_face_value(card_face, player_count)
    new_player_count = player_count + List.first(face_value)
    IO.inspect(List.last(face_value), label: "face value")

    game_state_add_ace_high =
      if List.last(face_value) do
        Map.put(game_state, :player_ace_high_count, game_state.player_ace_high_count + 1)
      else
        game_state
      end

    game_state_add_card =
      Map.put(game_state_add_ace_high, :player_cards, game_state.player_cards ++ [card_full])

    game_state_add_count = Map.put(game_state_add_card, :player_count, new_player_count)

    check_ace_high(game_state_add_count, :player)
    |> check_player_bust()
  end

  def hit(game_state, :dealer) do
    # Create Lists for random card and generate it
    suits = ["H", "S", "D", "C"]
    face = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    card_face = Enum.random(face)
    card_suits = Enum.random(suits)
    card_full = card_face <> "-" <> card_suits
    # Get players current count
    dealer_count = Map.get(game_state, :dealer_count)
    # Get point value of face card, and whether or not its ace high (Ex. if "A" [10, true])
    face_value = get_face_value(card_face, dealer_count)
    new_dealer_count = dealer_count + List.first(face_value)
    dealer_card_count = length(game_state.dealer_cards)
    IO.inspect(dealer_card_count)

    game_state_add_ace_high =
      if List.last(face_value) do
        Map.put(game_state, :dealer_ace_high_count, game_state.dealer_ace_high_count + 1)
      else
        game_state
      end

    game_state_add_card =
      if dealer_card_count == 1 do
        Map.put(game_state_add_ace_high, :dealer_cards, game_state.dealer_cards ++ ["BACK"])
        |> Map.put(:dealer_hidden_card, card_full)
      else
        Map.put(game_state_add_ace_high, :dealer_cards, game_state.dealer_cards ++ [card_full])
      end

    game_state_add_count = Map.put(game_state_add_card, :dealer_count, new_dealer_count)
    check_ace_high(game_state_add_count, :dealer)
  end

  def check_ace_high(game_state, :dealer) do
    ace_high_count = game_state.dealer_ace_high_count
    dealer_count = game_state.dealer_count

    if game_state.dealer_count > 21 and ace_high_count > 0 do
      game_state_remove_ace_high_count =
        Map.put(game_state, :dealer_ace_high_count, ace_high_count - 1)

      game_state_remove_ace_high_points =
        Map.put(game_state_remove_ace_high_count, :dealer_count, dealer_count - 10)

      check_ace_high(game_state_remove_ace_high_points, :dealer)
    else
      game_state
    end
  end

  def check_ace_high(game_state, :player) do
    ace_high_count = game_state.player_ace_high_count
    player_count = game_state.player_count

    if game_state.player_count > 21 and ace_high_count > 0 do
      game_state_remove_ace_high_count =
        Map.put(game_state, :player_ace_high_count, ace_high_count - 1)

      game_state_remove_ace_high_points =
        Map.put(game_state_remove_ace_high_count, :player_count, player_count - 10)

      check_ace_high(game_state_remove_ace_high_points, :player)
    else
      game_state
    end
  end

  def get_face_value(face, player_count) do
    over_21 = player_count + 10 > 21

    cond do
      face == "A" and over_21 -> [1, false]
      face == "A" -> [11, true]
      face == "2" -> [2, false]
      face == "3" -> [3, false]
      face == "4" -> [4, false]
      face == "5" -> [5, false]
      face == "6" -> [6, false]
      face == "7" -> [7, false]
      face == "8" -> [8, false]
      face == "9" -> [9, false]
      true -> [10, false]
    end
  end

  def player_stands(game_state) do
    if game_state.dealer_count < 17 do
      game_state_after_hit = hit(game_state, :dealer)
      player_stands(game_state_after_hit)
    else
      new_dealer_cards =
        List.replace_at(game_state.dealer_cards, 1, game_state.dealer_hidden_card)

      dealer_bust = game_state.dealer_count > 21
      player_won = dealer_bust or game_state.player_count > game_state.dealer_count

      Map.put(game_state, :dealer_cards, new_dealer_cards)
      |> Map.put(:dealer_bust, dealer_bust)
      |> Map.put(:player_won, player_won)
      |> Map.put(:hand_over, true)
      |> Map.put(:player_bet, 0)
    end
  end

  def check_player_bust(game_state) do
    if game_state.player_count > 21 do
      Map.put(game_state, :player_won, false)
      |> Map.put(:hand_over, true)
    else
      game_state
    end
  end

  def initial_deal(game_state) do
    initial_deal =
      hit(game_state, :player)
      |> hit(:dealer)
      |> hit(:player)
      |> hit(:dealer)

    initial_deal
  end

  def reset_table(player_id, player_name, table_seat, table_id) do
    initial_game_state(player_id, player_name, table_seat, table_id)
  end
end
