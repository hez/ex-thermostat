defmodule ExThermostatWeb.LiveComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ExThermostatWeb.Components

  @adjustment_amount 0.5

  @impl true
  def handle_event("toggle_heat", _params, socket) do
    socket.assigns.thermostat_implementation.toggle_mode(:heat)

    {:noreply, socket}
  end

  def handle_event("toggle_cool", _params, socket) do
    socket.assigns.thermostat_implementation.toggle_mode(:cool)

    {:noreply, socket}
  end

  @impl true
  def handle_event("target_down", _, socket) do
    socket.assigns.thermostat_implementation.adjust_target_by(-@adjustment_amount)
    {:noreply, socket}
  end

  @impl true
  def handle_event("target_up", _, socket) do
    socket.assigns.thermostat_implementation.adjust_target_by(@adjustment_amount)
    {:noreply, socket}
  end

  attr(:status, :map, required: false)
  attr(:show_heater, :boolean, default: true)
  attr(:show_cooler, :boolean, default: true)
  attr(:show_fan, :boolean, default: false)

  def render(assigns) do
    assigns =
      assigns
      |> assign(:thermostat_temperature_colour, thermostat_temperature_colour(assigns[:status]))
      |> assign(:show_temperature_controls, show_temperature_controls(assigns[:status]))

    ~H"""
    <div class="component flex flex-row mx-2">
      <div
        :if={@show_heater}
        class="component flex flex-row border-2 border-solid border-blue-600 rounded-2xl mx-2"
        phx-click="toggle_heat"
        phx-target={@myself}
      >
        <div class="ml-2 mt-2">
          <.fire_icon class={if @status.mode == :heat, do: "fill-red-600", else: "fill-gray-500"} />
        </div>

        <.toggle on={@status.mode == :heat} />

        <div class="px-4 py-2 text-4xl">
          Furnace
        </div>
      </div>

      <div
        :if={@show_cooler}
        class="component flex flex-row border-2 border-solid border-blue-600 rounded-2xl px-2"
        phx-click="toggle_cool"
        phx-target={@myself}
      >
        <div class="ml-2 mt-2">
          <.air_conditioner_icon class={
            if @status.mode == :cool, do: "fill-blue-600", else: "fill-gray-500"
          } />
        </div>

        <.toggle on={@status.mode == :cool} />

        <div class="px-4 py-2 text-4xl">
          A/C
        </div>
      </div>

      <div :if={@show_fan} class="px-4 py-2">
        <.fan_icon class={if @status.mode == :fan, do: "fill-blue-600", else: "fill-gray-500"} />
      </div>

      <div :if={@show_temperature_controls} class="component flex flex-row">
        <div class="px-4 py-2" phx-click="target_down" phx-target={@myself}>
          <.caret_down_filled_icon class="fill-blue-600" />
        </div>

        <div class={["px-4 py-2 text-4xl", @thermostat_temperature_colour]}>
          {@status.target}&#176;C
        </div>

        <div class="px-4 py-2" phx-click="target_up" phx-target={@myself}>
          <.caret_up_filled_icon class="fill-blue-600" />
        </div>
      </div>
    </div>
    """
  end

  attr(:status, :map, required: false)

  def current_temperature(assigns) do
    ~H"""
    <div class="text-4xl flex">
      <div><span name="hero-home-solid" class="h-10 w-10 mr-4 stroke-amber-600" /></div>
      <.temperature_display sensor={@status} />
    </div>
    """
  end

  attr(:sensor, :map, required: false)

  def temperature_display(assigns) do
    ~H"""
    <div>
      <%= if not is_nil(@sensor) do %>
        <b>{Float.round(@sensor.temperature, 1)}&#176;C</b>
        at <b>{@sensor.humidity |> Float.round(0) |> trunc()}%</b>
      <% else %>
        n/a
      <% end %>
    </div>
    """
  end

  defp show_temperature_controls(%{mode: mode}) when mode == :heat or mode == :cool, do: true
  defp show_temperature_controls(_), do: false

  defp thermostat_temperature_colour(%{mode: mode, target: target, temperature: temperature})
       when mode == :heat and target > temperature,
       do: "text-red-600"

  defp thermostat_temperature_colour(%{mode: mode, target: target, temperature: temperature})
       when mode == :cool and target < temperature,
       do: "text-blue-600"

  defp thermostat_temperature_colour(_), do: nil
end
