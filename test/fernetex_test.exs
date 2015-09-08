defmodule FernetTest do
  use ExUnit.Case, async: true

  test "generate" do
    {:ok, cs} = load_fixture("generate")
    expected_tokens = cs |> Enum.map(&({:ok, :erlang.list_to_binary(&1["iv"]), &1["token"]}))
    actual_tokens = cs |> Enum.map(&generate/1)
    assert expected_tokens == actual_tokens
  end

  defp generate(args) do
    Fernet.generate(message: args["src"], secret: args["secret"],
                    iv: args["iv"], now: args["now"])
  end

  defp load_fixture(fixture_name) do
    File.read!("fixtures/#{fixture_name}.json")
    |> JSON.decode
  end
end
