defmodule Fernet.Mixfile do
  use Mix.Project

  def project do
    [app: :fernetex,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :tzdata]]
  end

  defp package do
    [
      description: "Elixir implementation of Fernet library based on https://github.com/fernet/spec",
      files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Kenny Parnell"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/kennyp/fernetex"}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:json, "~> 0.3.0"},
     {:timex, "~> 0.19.3"}]
  end
end
