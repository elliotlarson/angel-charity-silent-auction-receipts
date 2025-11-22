defmodule Receipts.MixProject do
  use Mix.Project

  def project do
    [
      app: :receipts,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:nimble_csv, "~> 1.2"},
      {:ecto, "~> 3.11"},
      {:req, "~> 0.5.0"},
      {:dotenvy, "~> 0.8.0"}
    ]
  end
end
