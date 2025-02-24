defmodule ExThermostat.MixProject do
  use Mix.Project

  @version "0.2.0"
  def project do
    [
      app: :ex_thermostat,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExThermostat.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_gpio, "~> 2.0"},
      {:dht, "~> 0.1"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:phoenix_live_view, "~> 1.0"},
      {:pid_controller, "~> 0.1.3"}
    ]
  end
end
