defmodule ExThermostat.Supervisor do
  @moduledoc false
  use Supervisor
  require Logger

  @name __MODULE__

  def start_link(opts), do: Supervisor.start_link(@name, opts, name: @name)

  @impl true
  def init(opts) do
    children =
      [
        {Phoenix.PubSub, name: ExThermostat.PubSub},
        {ExThermostat.PID, Keyword.get(opts, :pid_settings, [])},
        {ExThermostat, Keyword.get(opts, :settings, [])}
      ] ++
        child_proc(Keyword.get(opts, :sensor_config)) ++
        child_proc(Keyword.get(opts, :io_config))

    Supervisor.init(children, strategy: :one_for_one)
  end

  def child_proc(nil), do: []
  def child_proc(child), do: [child]
end
