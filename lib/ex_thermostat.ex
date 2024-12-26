defmodule ExThermostat do
  @moduledoc """
  `Thermostat`
  """

  use GenServer

  require Logger
  import ExThermostat.PubSub, only: [subscribe: 1, broadcast: 1, broadcast: 2]

  alias ExThermostat.Status

  @name __MODULE__
  @poll_interval 30 * 1000
  @default_options [
    # Minimum heater runtime in minutes
    minimum_runtime: nil,
    minimum_target: 10,
    maximum_target: 30,
    poll_interval: @poll_interval,
    winter_end: ~D[2000-04-01],
    winter_mode_enabled: true,
    winter_start: ~D[2000-10-01],
    winter_target_temperature: 16.0
  ]

  def start_link(opts \\ []) do
    options = Keyword.merge(@default_options, opts)
    GenServer.start_link(@name, %{status: nil, options: options}, name: @name)
  end

  @impl true
  def init(%{options: options} = state) do
    queue_poll(options)
    subscribe(:temperature)
    {:ok, %{state | status: initial_status(options)}}
  end

  @spec status() :: Status.t()
  def status, do: GenServer.call(@name, :status)

  @spec options(atom()) :: any()
  def options(key) when is_atom(key),
    do: @name |> GenServer.call(:options) |> Keyword.get(key)

  @spec start_heat() :: :ok
  def start_heat, do: GenServer.cast(@name, {:set_heating, true})
  @spec stop_heat() :: :ok
  def stop_heat, do: GenServer.cast(@name, {:set_heating, false})

  @spec adjust_target_by(float()) :: :ok | {:error, atom()}
  def adjust_target_by(value) when is_float(value), do: set_target(status().target + value)

  @spec set_target(float() | integer()) :: :ok | {:error, atom()}
  def set_target(target) when is_integer(target), do: set_target(target / 1.0)

  @spec set_target(float()) :: :ok | {:error, atom()}
  def set_target(target) do
    if target > options(:minimum_target) and target <= options(:maximum_target) do
      GenServer.cast(@name, {:set_target, target})
      :ok
    else
      Logger.warning("set temperature outside range val: #{inspect(target)}")
      {:error, :outside_range}
    end
  end

  @spec initial_status(Keyword.t()) :: Status.t()
  def initial_status(options) do
    if Keyword.get(options, :winter_mode_enabled, true) and
         winter_mode?(options, Date.utc_today()) do
      %Status{heating: true, target: Keyword.get(options, :winter_target_temperature)}
    else
      %Status{}
    end
  end

  @spec winter_mode?(Keyword.t(), Date.t()) :: boolean()
  def winter_mode?(options, date) do
    Date.compare(date, %{Keyword.get(options, :winter_start) | year: date.year}) === :gt or
      Date.compare(date, %{Keyword.get(options, :winter_end) | year: date.year}) === :lt
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  @impl true
  def handle_call(:options, _from, state), do: {:reply, state.options, state}

  @impl true
  def handle_cast({:set_heating, value}, state) when is_boolean(value) do
    state = update_status(state, :heating, value)
    broadcast(:thermostat, {:heating, value})
    broadcast(:thermostat_status, {:thermostat, state.status})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_target, new_target}, state) do
    state = update_status(state, :target, new_target)
    ExThermostat.PID.update_set_point(new_target)
    broadcast(:thermostat, {:target, new_target})
    broadcast(:thermostat_status, {:thermostat, state.status})
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, %{status: %Status{heating: true} = status} = state) do
    output = ExThermostat.PID.output(status.temperature)

    state =
      state
      |> update_status(:pid, output)
      |> update_state_and_broadcast()
      |> tap(&Logger.debug(inspect(&1), label: :new_state_from_poll))

    broadcast(:thermostat_status, {:thermostat, state.status})
    queue_poll(state.options)
    {:noreply, state}
  end

  def handle_info(:poll, %{} = state) do
    queue_poll(state.options)
    {:noreply, state}
  end

  @impl true
  def handle_info(%{temperature: new_t, humidity: new_h}, %{} = state) do
    Logger.debug("got new temp and hum, #{new_t} / #{new_h}")
    state = state |> update_status(:temperature, new_t) |> update_status(:humidity, new_h)

    broadcast(
      thermostat: {:humidity, new_t},
      thermostat: {:temperature, new_t},
      thermostat_status: {:thermostat, state.status}
    )

    {:noreply, state}
  end

  @spec update_status(map(), atom(), any()) :: map()
  defp update_status(%{status: %Status{} = status} = state, key, value) when is_atom(key),
    do: %{state | status: ExThermostat.Status.update(status, key, value)}

  defp queue_poll(options) when is_list(options),
    do: Process.send_after(self(), :poll, Keyword.get(options, :poll_interval, @poll_interval))

  # Heating ON
  defp update_state_and_broadcast(%{status: %Status{heating: true, pid: pid_val}} = state)
       when pid_val > 0 do
    broadcast(:heater, {:heater, true})

    state.status.heater_on
    |> case do
      # Transition to heating on
      false -> state |> update_status(:heater_started_at, DateTime.utc_now())
      _ -> state
    end
    |> update_status(:heater_on, true)
  end

  defp update_state_and_broadcast(%{} = state) do
    case can_shutdown?(state) do
      true ->
        broadcast(:heater, {:heater, false})
        state |> update_status(:heater_on, false) |> update_status(:heater_started_at, nil)

      false ->
        Logger.warning("Can't shutdown heater yet")
        state
    end
  end

  defp can_shutdown?(%{options: options, status: %Status{} = status}) do
    with true <- status.heating,
         true <- status.heater_on,
         heater_started_at when not is_nil(heater_started_at) <- status.heater_started_at,
         min_rt when not is_nil(min_rt) <- Keyword.get(options, :minimum_runtime) do
      heater_started_at
      |> DateTime.shift(minute: min_rt)
      |> DateTime.compare(DateTime.utc_now()) == :lt
    else
      _ -> true
    end
  end
end
