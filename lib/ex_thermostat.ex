defmodule ExThermostat do
  @moduledoc """
  `Thermostat`
  """
  @callback status() :: ExThermostat.Status.t()
  @callback set_mode(atom()) :: :ok | :error
  @callback toggle_mode(atom()) :: :ok | :error
  @callback set_target(float()) :: :ok | :error
  @callback adjust_target_by(float()) :: :ok | :error

  use GenServer

  require Logger
  import ExThermostat.PubSub, only: [subscribe: 1, broadcast: 1, broadcast: 2]

  alias ExThermostat.Status

  @name __MODULE__
  @poll_interval 30 * 1000
  @default_options [
    # Minimum heater runtime in minutes
    minimum_target: 10,
    maximum_target: 30,
    poll_interval: @poll_interval,
    status: %Status{}
  ]

  def start_link(opts \\ []) do
    options = Keyword.merge(@default_options, opts)
    status = Keyword.get(options, :status)

    GenServer.start_link(@name, %{status: status, options: options}, name: @name)
  end

  @impl true
  def init(%{options: options} = state) do
    queue_poll(options)
    subscribe(:temperature)
    {:ok, state}
  end

  @spec status() :: map()
  def status, do: GenServer.call(@name, :status)
  @spec update_status(atom(), any()) :: any()
  def update_status(key, value), do: update_status(%{key => value})
  @spec update_status(map()) :: any()
  def update_status(map), do: GenServer.cast(@name, {:update_status, map})

  @spec options(atom()) :: any()
  def options(key) when is_atom(key),
    do: @name |> GenServer.call(:options) |> Keyword.get(key)

  @spec start_heat(map()) :: :ok
  def start_heat(new_status \\ %{}), do: new_status |> Map.put(:heating, true) |> update_status()
  @spec stop_heat(map()) :: :ok
  def stop_heat(new_status \\ %{}), do: new_status |> Map.put(:heating, false) |> update_status()

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

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  @impl true
  def handle_call(:options, _from, state), do: {:reply, state.options, state}

  @impl true
  def handle_cast({:update_status, values}, state) do
    state =
      Enum.reduce(values, state, fn {key, value}, acc ->
        acc = update_status(acc, key, value)
        broadcast(:thermostat, {key, value})
        broadcast(:thermostat_status, {:thermostat, acc.status})
        acc
      end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_target, new_target}, state) do
    state = update_status(state, :target, new_target)
    pid_impl().update_set_point(new_target)
    broadcast(:thermostat, {:target, new_target})
    broadcast(:thermostat_status, {:thermostat, state.status})
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, %{status: %{heating: true} = status} = state) do
    output = pid_impl().output(status.temperature)

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
  defp update_status(%{status: status} = state, key, value) when is_atom(key),
    do: %{state | status: Map.put(status, key, value)}

  defp queue_poll(options) when is_list(options),
    do: Process.send_after(self(), :poll, Keyword.get(options, :poll_interval, @poll_interval))

  # Heating ON
  defp update_state_and_broadcast(%{status: %{heating: true, pid: pid_val}} = state)
       when pid_val > 0 do
    broadcast(:heater, {:heater, true})

    case state.status.heater_on do
      # Transition to heating on
      false -> state |> update_status(:heater_started_at, DateTime.utc_now())
      _ -> state
    end
  end

  # Heating OFF
  defp update_state_and_broadcast(%{} = state) do
    case can_shutdown?(state) do
      true ->
        broadcast(:heater, {:heater, false})
        update_status(state, :heater_started_at, nil)

      false ->
        Logger.warning("Can't shutdown heater yet, can_shutdown?/1 returned false")
        state
    end
  end

  defp can_shutdown?(%{status: status}) do
    with true <- status.heating,
         heater_started_at when not is_nil(heater_started_at) <-
           Map.get(status, :heater_started_at, nil),
         min_rt when is_struct(min_rt, Duration) <- Map.get(status, :minimum_runtime, nil) do
      heater_started_at
      |> DateTime.shift(min_rt)
      |> DateTime.compare(DateTime.utc_now()) == :lt
    else
      _ -> true
    end
  end

  defp pid_impl, do: Application.get_env(:ex_thermostat, :pid_implementation, ExThermostat.PID)
end
