defmodule ExThermostat.PubSub do
  @moduledoc false
  @topics %{
    fan: "fan_io_update",
    heater: "heater_io_update",
    temperature: "temperature_update",
    thermostat: "thermostat_update",
    thermostat_status: "thermostat_status"
  }

  @type topic() :: :fan | :heater | :temperature | :thermostat | :thermostat_status
  @type event() :: any()
  @type broadcast_return() :: :ok | {:error, term()}

  @spec subscribe(topic()) :: :ok
  def subscribe(topic), do: Phoenix.PubSub.subscribe(__MODULE__, topic_name(topic))

  @spec topic_name(topic() | String.t()) :: String.t()
  def topic_name(name) when is_atom(name), do: @topics[name]
  def topic_name(name) when is_binary(name), do: name

  @spec broadcast(list({topic(), event()})) :: broadcast_return()
  @spec broadcast({topic(), event()}) :: broadcast_return()
  @spec broadcast({topic(), list(event())}) :: broadcast_return()
  @spec broadcast(topic(), list(event())) :: broadcast_return()
  @spec broadcast(topic(), event()) :: broadcast_return()
  def broadcast(events) when is_list(events), do: Enum.map(events, &broadcast/1)
  def broadcast({topic, event}), do: broadcast(topic, event)
  def broadcast(topic, event), do: Phoenix.PubSub.broadcast(__MODULE__, topic_name(topic), event)
end
