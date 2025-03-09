defmodule ExThermostatTest do
  use ExUnit.Case
  doctest ExThermostat

  setup do
    ex_thermostat = ExThermostat.start_link()
    {:ok, ex_thermostat: ex_thermostat}
  end

  describe "status/0" do
    test "returns the status", %{ex_thermostat: ex_thermostat} do
      status = ExThermostat.status()
    end
  end
end
