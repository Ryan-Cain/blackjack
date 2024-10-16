defmodule BlackjackWeb.PlayerSessionController do
  use BlackjackWeb, :controller

  alias Blackjack.Accounts
  alias BlackjackWeb.PlayerAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:player_return_to, ~p"/players/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(
         conn,
         %{"player" => %{"login" => login, "password" => password} = player_params},
         info
       ) do
    # Check if the login is an email or a username
    player =
      if String.contains?(login, "@") do
        # Login is an email
        Accounts.get_player_by_email_and_password(login, password)
      else
        # Login is a username
        Accounts.get_player_by_username_and_password(login, password)
      end

    if player do
      conn
      |> put_flash(:info, info)
      |> PlayerAuth.log_in_player(player, player_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid username/email or password")
      |> put_flash(:login, String.slice(login, 0, 160))
      |> redirect(to: ~p"/players/log_in")
    end
  end

  defp create(
         conn,
         %{
           "player" => %{"email" => email, "password" => password} = player_params
         },
         info
       ) do
    # Check if the login is an email or a username
    player = Accounts.get_player_by_email_and_password(email, password)

    if player do
      conn
      |> put_flash(:info, info)
      |> PlayerAuth.log_in_player(player, player_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid username/email or password")
      |> put_flash(:login, String.slice(email, 0, 160))
      |> redirect(to: ~p"/players/log_in")
    end
  end

  # defp do_create(conn, player, player_params, info) do
  #   if player do
  #     conn
  #     |> put_flash(:info, info)
  #     |> PlayerAuth.log_in_player(player, player_params)
  #   else
  #     # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
  #     conn
  #     |> put_flash(:error, "Invalid username/email or password")
  #     |> put_flash(:login, String.slice(login, 0, 160))
  #     |> redirect(to: ~p"/players/log_in")
  #   end
  # end

  def delete(conn, _params) do
    IO.inspect("hit delete")

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> PlayerAuth.log_out_player()
  end
end
