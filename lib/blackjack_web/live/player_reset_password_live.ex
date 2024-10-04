defmodule BlackjackWeb.PlayerResetPasswordLive do
  use BlackjackWeb, :live_view

  alias Blackjack.Accounts

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
          <span class="header-msg">Reset Password!</span>
        </.header>

        <.simple_form
          for={@form}
          id="reset_password_form"
          phx-submit="reset_password"
          phx-change="validate"
        >
          <.error :if={@form.errors != []}>
            Oops, something went wrong! Please check the errors below.
          </.error>
          <.input field={@form[:password]} type="password" label="New password" required />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            required
          />
          <:actions>
            <.button
              phx-disable-with="Creating account..."
              class="w-full text-xl bg-green-600 transition duration-300 ease-in-out hover:bg-green-500 play-btn"
            >
              <span>
                Reset Password!
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

  # def render(assigns) do
  #   ~H"""
  #   <div class="mx-auto max-w-sm">
  #     <.header class="text-center">Reset Password</.header>

  #     <.simple_form
  #       for={@form}
  #       id="reset_password_form"
  #       phx-submit="reset_password"
  #       phx-change="validate"
  #     >
  #       <.error :if={@form.errors != []}>
  #         Oops, something went wrong! Please check the errors below.
  #       </.error>

  #       <.input field={@form[:password]} type="password" label="New password" required />
  #       <.input
  #         field={@form[:password_confirmation]}
  #         type="password"
  #         label="Confirm new password"
  #         required
  #       />
  #       <:actions>
  #         <.button phx-disable-with="Resetting..." class="w-full">Reset Password</.button>
  #       </:actions>
  #     </.simple_form>

  #     <p class="text-center text-sm mt-4">
  #       <.link href={~p"/players/register"}>Register</.link>
  #       | <.link href={~p"/players/log_in"}>Log in</.link>
  #     </p>
  #   </div>
  #   """
  # end

  def mount(params, _session, socket) do
    socket = assign_player_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{player: player} ->
          Accounts.change_player_password(player)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the player after reset password to avoid a
  # leaked token giving the player access to the account.
  def handle_event("reset_password", %{"player" => player_params}, socket) do
    case Accounts.reset_player_password(socket.assigns.player, player_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/players/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"player" => player_params}, socket) do
    changeset = Accounts.change_player_password(socket.assigns.player, player_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_player_and_token(socket, %{"token" => token}) do
    if player = Accounts.get_player_by_reset_password_token(token) do
      assign(socket, player: player, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "player"))
  end
end
