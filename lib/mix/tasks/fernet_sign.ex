defmodule Mix.Tasks.Fernet.Sign do
  @moduledoc """
  Sign STDIN using the given key

      mix fernet.sign key
  """

  use Mix.Task

  @shortdoc "Sign STDIN using fernet"

  def run([key]) do
    {:ok, _} = Application.ensure_all_started(:timex)

    :stdio
    |> IO.read(:all)
    |> Fernet.generate(key: key)
    |> elem(2)
    |> Mix.shell().info
  end

  def run(_args) do
    Mix.raise("usage: mix fernet.sign key")
  end
end
