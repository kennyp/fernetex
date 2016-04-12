defmodule Mix.Tasks.Fernet.Keygen do
  @moduledoc """
  Generate a new Fernet key

      mix fernet.keygen
  """

  use Mix.Task

  @shortdoc "Generate a new Fernet key"

  def run(_args) do
    Fernet.generate_key
    |> Mix.shell.info
  end
end
