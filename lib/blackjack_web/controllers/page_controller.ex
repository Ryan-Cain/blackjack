defmodule BlackjackWeb.PageController do
  use BlackjackWeb, :controller

  alias Blackjack.Logic.GameLogic

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    # initial = GameLogic.initial_game_state()
    # IO.inspect(initial)
    # updated = GameLogic.hit(initial, :player)
    # IO.inspect(updated)
    initial = GameLogic.initial_deal()
    IO.inspect(initial)
    render(conn, :home, layout: false, game_state: initial)
  end
end
