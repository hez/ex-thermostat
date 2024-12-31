defmodule ExThermostatWeb.LiveComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ExThermostatWeb.Components

  @adjustment_amount 0.5

  @impl true
  def handle_event("furnace_toggle", _, socket) do
    if socket.assigns.status.heating do
      socket.assigns.thermostat_implementation.stop_heat()
    else
      socket.assigns.thermostat_implementation.start_heat()
    end

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
  attr(:show_fan, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <div class="component flex flex-row mx-2">
      <.toggle on={@status.heating} phx_click="furnace_toggle" phx_target={@myself}>
        Furnace
      </.toggle>

      <div class="px-4 py-2" :if={@show_heater}>
        <.fire_icon class={if @status.heater_on, do: "fill-red-600", else: "fill-gray-500"} />
      </div>

      <div class="px-4 py-2" :if={@show_fan}>
        <.fan_icon class={if @status.fan_on, do: "fill-blue-600", else: "fill-gray-500"} />
      </div>

      <%= if @status.heating do %>
        <div class="px-4 py-2" phx-click="target_down" phx-target={@myself}>
          <.caret_down_filled_icon class="fill-blue-600" />
        </div>

        <div class={"px-4 py-2 text-4xl#{if @status.target > @status.temperature, do: " text-red-600"}"}>
          {@status.target}&#176;C
        </div>

        <div class="px-4 py-2" phx-click="target_up" phx-target={@myself}>
          <.caret_up_filled_icon class="fill-blue-600" />
        </div>
      <% end %>
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
end
