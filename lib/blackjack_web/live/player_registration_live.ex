defmodule BlackjackWeb.PlayerRegistrationLive do
  use BlackjackWeb, :live_view

  alias Blackjack.Accounts
  alias Blackjack.Accounts.Player

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
      <div id="login-reg-form" class="mx-auto">
        <.header class="text-center">
          <span class="header-msg">Register for an account!</span>
          <:subtitle>
            Already registered?
            <.link
              navigate={~p"/players/log_in"}
              class="font-bold text-base text-green-400 hover:underline"
            >
              Log in here
            </.link>
          </:subtitle>
        </.header>

        <.simple_form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/players/log_in?_action=registered"}
          method="post"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>
          <.input field={@form[:name]} type="text" label="Username" required />
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.button
              phx-disable-with="Creating account..."
              class="w-full text-xl bg-green-600 transition duration-300 ease-in-out hover:bg-green-500 play-btn"
            >
              <span>
                Create account!
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
    changeset = Accounts.change_player_registration(%Player{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"player" => player_params}, socket) do
    case Accounts.register_player(player_params) do
      {:ok, player} ->
        {:ok, _} =
          Accounts.deliver_player_confirmation_instructions(
            player,
            &url(~p"/players/confirm/#{&1}")
          )

        changeset = Accounts.change_player_registration(player)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"player" => player_params}, socket) do
    changeset = Accounts.change_player_registration(%Player{}, player_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "player")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
