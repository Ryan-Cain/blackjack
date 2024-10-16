defmodule BlackjackWeb.Router do
  use BlackjackWeb, :router

  import BlackjackWeb.PlayerAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BlackjackWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_player
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  ## Authentication routes

  scope "/", BlackjackWeb do
    pipe_through [:browser, :redirect_if_player_is_authenticated]

    live_session :redirect_if_player_is_authenticated,
      on_mount: [{BlackjackWeb.PlayerAuth, :redirect_if_player_is_authenticated}] do
      live "/players/register", PlayerRegistrationLive, :new
      live "/players/log_in", PlayerLoginLive, :new
      live "/players/reset_password", PlayerForgotPasswordLive, :new
      live "/players/reset_password/:token", PlayerResetPasswordLive, :edit
    end

    post "/players/log_in", PlayerSessionController, :create
  end

  scope "/", BlackjackWeb do
    pipe_through [:browser]

    delete "/players/log_out", PlayerSessionController, :delete

    live_session :current_player,
    on_mount: [{BlackjackWeb.PlayerAuth, :mount_current_player}] do
      live "/players/confirm/:token", PlayerConfirmationLive, :edit
      live "/players/confirm", PlayerConfirmationInstructionsLive, :new
    end
  end

  scope "/", BlackjackWeb do
    pipe_through [:browser, :require_authenticated_player]

    live_session :require_authenticated_player,
      on_mount: [{BlackjackWeb.PlayerAuth, :ensure_authenticated}] do
        live "/players/settings", PlayerSettingsLive, :edit
      live "/players/:id", PlayerLive.Show, :show
      live "/players/settings/confirm_email/:token", PlayerSettingsLive, :confirm_email
      live "/tables/:id/players/:user_id", TableLive.Play, :play
      live "/players/:id/edit", PlayerLive.Index, :edit

      live "/players/:id/show/edit", PlayerLive.Show, :edit

      live "/tables", TableLive.Index, :index
      live "/tables/new", TableLive.Index, :new
      live "/tables/:id", TableLive.Play, :play
      live "/tables/:id/edit", TableLive.Index, :edit
    end
  end


  scope "/", BlackjackWeb do
    pipe_through :browser

    get "/", PageController, :home

    # live "/players", PlayerLive.Index, :index
    # live "/players/new", PlayerLive.Index, :new
    # live "/players/:id/game", PlayerLive.Show, :game

    # live "/tables/:id", TableLive.Show, :show
    # live "/tables/:id/", TableLive.Play, :play
    # live "/tables/:id/show/edit", TableLive.Show, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", BlackjackWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:blackjack, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BlackjackWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
