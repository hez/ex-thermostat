defmodule ExThermostat.DummyHeater do
  @moduledoc false
  use GenServer
  require Logger

  @name __MODULE__

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: @name)

  @impl true
  def init(state) do
    ExThermostat.PubSub.subscribe(:heater)
    {:ok, state}
  end

  @impl true
  def handle_info({:heater, val}, state) do
    Logger.warning("Turning heater to new value #{inspect(val)}")
    {:noreply, state}
  end
end
