defmodule BlackjackWeb.PlayerForgotPasswordLive do
  use BlackjackWeb, :live_view

  alias Blackjack.Accounts

  def render(assigns) do
    ~H"""
    <div class="flex justify-center items-center h-screen w-screen relative forgot-password">
      <div id="unhelpful-reset-msg" class="ml-24 mb-36 welcome-message">
        <h1>Sorry you forgot the password!</h1>
        <p>
          Unfortunately that means <span id="win-msg">ALL</span>
        </p>
        <p>of your chips belong to us!!</p>
        <div style="text-align: center">
          <.button
            id="sike-btn"
            phx-disable-with="Sending..."
            class="mt-48 text-xl bg-green-600 transition duration-300 ease-in-out hover:bg-green-500 play-btn"
            phx-click={
              JS.show(to: "#login-reg-form")
              |> JS.show(to: "#helpful-reset-msg")
              |> JS.hide(to: "#sike-btn")
              |> JS.hide(to: "#unhelpful-reset-msg")
            }
          >
            Sike! Just click here
          </.button>
        </div>
      </div>
      <div id="helpful-reset-msg" class="ml-24 mb-36 welcome-message hidden">
        <h1>Please just fill out the form</h1>
        <p>
          And we will send you an email
        </p>
        <p>to reset your password!!</p>
      </div>
      <div id="login-reg-form" class="mx-auto hidden">
        <.header class="text-center">
          <span class="header-msg">Forgot your password?</span>
        </.header>

        <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
          <.error :if={@form.errors != []}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <:actions>
            <.button
              phx-disable-with="Sending..."
              class="w-full text-xl bg-green-600 transition duration-300 ease-in-out hover:bg-green-500 play-btn"
            >
              <span>
                Send password reset instructions
              </span>
              <p>
                <span aria-hidden="true">→</span>
              </p>
            </.button>
          </:actions>
        </.simple_form>
        <p class="text-center text-sm mt-4">
          <.link href={~p"/players/register"}>Register</.link>
          | <.link href={~p"/players/log_in"}>Log in</.link>
        </p>
      </div>
      <h3 class="fixed left-1/2 transform -translate-x-1/2 bottom-5">
        IF YOU HAVE A GAMBLING PROBLEM, <span class="font-bold text-lg">CALL 1-800-GAMBLER</span>
      </h3>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "player"))}
  end

  def handle_event("send_email", %{"player" => %{"email" => email}}, socket) do
    if player = Accounts.get_player_by_email(email) do
      Accounts.deliver_player_reset_password_instructions(
        player,
        &url(~p"/players/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
