defmodule ExThermostat.Status do
  @moduledoc """
  Struct representing the thermostats current state.

  mode: :off | :fan | :heat | :cool | :auto
  equipment_state: :idle | :fan | :heating | :cooling
  started_at:
  target: target heating/cooling temp
  humidity: last humidity polled
  temperature: last temperature polled
  pid: last pid value recorded
  """
  defstruct mode: :off,
            equipment_state: :idle,
            started_at: nil,
            humidity: 0.0,
            target: 15.0,
            temperature: 15.0,
            pid: 0.0

  @type t :: %__MODULE__{
          mode: :off | :fan | :heat | :cool | :auto,
          equipment_state: :idle | :fan | :heating | :cooling,
          started_at: nil | DateTime.t(),
          humidity: float(),
          target: float(),
          temperature: float(),
          pid: float()
        }
end
