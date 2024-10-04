defmodule BlackjackWeb.PlayerLoginLive do
  use BlackjackWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex justify-center items-center h-screen w-screen relative">
      <div class="ml-24 mb-36 welcome-message">
        <h1>Welcome to Blackjack!</h1>
        <p>
          Log in to
          <span id="win-msg">WIN</span><span
            id="lose-msg"
            data-darkreader-ignore
            aria-hidden="true"
            role="presentation"
          >(or lose)</span>
        </p>
        <p>a whole bunch of money!!</p>
      </div>
      <div id="login-reg-form" class="mx-auto max-w-sm ">
        <.header class="text-center">
          <span class="header-msg">Log in to play!</span>
          <:subtitle>
            Don't have an account?
            <.link
              navigate={~p"/players/register"}
              class="font-bold text-base text-green-400 hover:underline"
            >
              Sign up here!
            </.link>
          </:subtitle>
        </.header>

        <.simple_form for={@form} id="login_form" action={~p"/players/log_in"} phx-update="ignore">
          <.input field={@form[:login]} type="text" label="Email or Username" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
            <.link href={~p"/players/reset_password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
          </:actions>
          <:actions>
            <.button
              phx-disable-with="Logging in..."
              class="w-full text-xl bg-green-600 transition duration-300 ease-in-out hover:bg-green-500 play-btn"
            >
              <span>
                Lets play!
              </span>
              <p>
                <span aria-hidden="true">→</span>
              </p>
            </.button>
          </:actions>
        </.simple_form>
      </div>
      <h3 class="fixed left-1/2 transform -translate-x-1/2 bottom-5">
        IF YOU HAVE A GAMBLING PROBLEM, <span class="font-bold text-lg">CALL 1-800-GAMBLER</span>
      </h3>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "player")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
