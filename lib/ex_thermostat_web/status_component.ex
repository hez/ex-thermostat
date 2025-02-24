defmodule ExThermostatWeb.StatusComponent do
  import Phoenix.LiveView
  use Phoenix.Component

  def on_mount(attrs, _params, _session, socket) do
    thermostat_implementation = Keyword.get(attrs, :thermostat_implementation, Thermostat)

    if connected?(socket) do
      ExThermostat.PubSub.subscribe(:thermostat_status)
    end

    {:cont,
     assign(socket,
       status: thermostat_implementation.status(),
       thermostat_implementation: thermostat_implementation
     )}
  end

  ### Thermostat Pubsub callbacks
  def handle_info(%ExThermostat.Status{} = status, socket),
    do: {:noreply, assign(socket, status: status)}
end
