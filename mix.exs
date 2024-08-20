defmodule Fernet.Mixfile do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :fernetex,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      docs: [
        source_ref: "v#{@version}",
        main: "Fernet",
        source_url: "https://github.com/kennyp/fernetex"
      ],
      dialyzer: [plt_file: {:no_warn, "priv/plts/dialyzer.plt"}],
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:eex, :logger]]
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
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.15", only: :dev},
      {:jason, "~> 1.0", only: [:dev, :test]},
      {:propcheck, "~> 1.0", only: :test}
    ]
  end
end
