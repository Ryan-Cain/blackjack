defmodule BlackjackWeb.PlayerLive.Show do
  use BlackjackWeb, :live_view

  # alias Blackjack.Tables
  alias Blackjack.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:player, Accounts.get_player!(id))}

    #  |> assign(:player, Tables.get_player!(id))}
  end

  defp page_title(:show), do: "Show Player"
  defp page_title(:edit), do: "Edit Player"
end
