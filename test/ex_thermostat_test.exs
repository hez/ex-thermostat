defmodule ExThermostatTest do
  use ExUnit.Case
  doctest ExThermostat

  setup do
    pub_sub = Phoenix.PubSub.start_link(name: ExThermostat.PubSub)
    ex_thermostat = ExThermostat.start_link()
    {:ok, ex_thermostat: ex_thermostat, pub_sub: pub_sub}
  end

  describe "status/0" do
    test "returns the status", %{ex_thermostat: ex_thermostat} do
      status = ExThermostat.status()
      dbg(status)
    end
  end
end
