defmodule BlackjackWeb.TableLive.FormComponent do
  use BlackjackWeb, :live_component

  alias Blackjack.Games

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage table records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="table-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:table_min]} type="number" label="Table min" />
        <.input field={@form[:countdown]} type="number" label="Countdown" />
        <.input field={@form[:table_color]} type="text" label="Table color" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Table</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{table: table} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Games.change_table(table))
     end)}
  end

  @impl true
  def handle_event("validate", %{"table" => table_params}, socket) do
    changeset = Games.change_table(socket.assigns.table, table_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"table" => table_params}, socket) do
    save_table(socket, socket.assigns.action, table_params)
  end

  defp save_table(socket, :edit, table_params) do
    case Games.update_table(socket.assigns.table, table_params) do
      {:ok, table} ->
        notify_parent({:saved, table})

        {:noreply,
         socket
         |> put_flash(:info, "Table updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_table(socket, :new, table_params) do
    case Games.create_table(table_params) do
      {:ok, table} ->
        notify_parent({:saved, table})

        {:noreply,
         socket
         |> put_flash(:info, "Table created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
