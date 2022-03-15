defmodule Fernet.Mixfile do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :fernetex,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      docs: [
        source_ref: "v#{@version}",
        main: "Fernet",
        source_url: "https://github.com/kennyp/fernetex"
      ],
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      description:
        "Elixir implementation of Fernet library based on https://github.com/fernet/spec",
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Kenny Parnell"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/kennyp/fernetex"}
    ]
  end

  defp deps do
    [
      {:timex, "~> 3.1"},

      # Dev & Test dependencies
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: :dev},
      {:earmark, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.15", only: :dev},
      {:poison, "~> 5.0", only: [:dev, :test]},
      {:propcheck, "~> 1.0", only: :test}
    ]
  end
end
