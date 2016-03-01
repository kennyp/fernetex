defmodule Fernet.Mixfile do
  use Mix.Project

  @version "0.0.2"

  def project do
    [app: :fernetex,
     version: @version,
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     docs: [source_ref: "v#{@version}", main: "Fernet",
            source_url: "https://github.com/kennyp/fernetex"],
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
    [{:earmark, "~> 0.2.0", only: [:dev]},
     {:ex_doc, "~> 0.11.3", only: [:dev]},
     {:credo, "~> 0.3.4", only: [:dev]},
     {:json, "~> 0.3.0", only: [:test]},
     {:timex, "~> 1.0"}]
  end
end
