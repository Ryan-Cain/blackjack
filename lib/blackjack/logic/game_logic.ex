defmodule Blackjack.Logic.GameLogic do
  def initial_game_state() do
    state = %{
      player_bet: 0,
      player_count: 0,
      player_cards: [],
      dealer_count: 0,
      dealer_cards: []
    }

    state
  end

  def hit(game_state, :player) do
    suits = ["H", "S", "D", "C"]
    face = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    card_face = Enum.random(face)
    card_suits = Enum.random(suits)
    card_full = card_face <> "-" <> card_suits
    player_count = Map.get(game_state, :player_count)
    face_value = get_face_value(card_face, player_count)
    new_player_count = player_count + face_value

    game_state_add_card =
      Map.put(game_state, :player_cards, [card_full | game_state.player_cards])

    game_state_add_count = Map.put(game_state_add_card, :player_count, new_player_count)
    game_state_add_count
  end

  def hit(game_state, :dealer) do
    suits = ["H", "S", "D", "C"]
    face = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    card_face = Enum.random(face)
    card_suits = Enum.random(suits)
    card_full = card_face <> "-" <> card_suits
    dealer_count = Map.get(game_state, :dealer_count)
    face_value = get_face_value(card_face, dealer_count)
    new_dealer_count = dealer_count + face_value

    game_state_add_card =
      Map.put(game_state, :dealer_cards, [card_full | game_state.dealer_cards])

    game_state_add_count = Map.put(game_state_add_card, :dealer_count, new_dealer_count)
    game_state_add_count
  end

  def get_face_value(face, player_count) do
    case face do
      face when face == "A" and not player_count + 10 > 21 -> 1
      face when face == "2" -> 2
      face when face == "3" -> 3
      face when face == "4" -> 4
      face when face == "5" -> 5
      face when face == "6" -> 6
      face when face == "7" -> 7
      face when face == "8" -> 8
      face when face == "9" -> 9
      face when true -> 10
    end
  end

  def initial_deal() do
    state =
      initial_game_state()
      |> hit(:player)
      |> hit(:dealer)
      |> hit(:player)
      |> hit(:dealer)

    state
  end
end
