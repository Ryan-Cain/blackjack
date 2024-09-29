defmodule BlackjackWeb.PageController do
  use BlackjackWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
