defmodule FernetTest do
  use ExUnit.Case, async: true
  doctest Fernet

  test "generate" do
    {:ok, cs} = load_fixture("generate")
    expected_tokens = cs |> Enum.map(&({:ok, :erlang.list_to_binary(&1["iv"]), &1["token"]}))
    actual_tokens = cs |> Enum.map(&generate/1)
    assert expected_tokens == actual_tokens
  end

  test "verify" do
    {:ok, cs} = load_fixture("verify")
    expected_keys = cs |> Enum.map(&({:ok, &1["src"]}))
    actual_keys = cs |> Enum.map(&verify/1)
    assert expected_keys == actual_keys
  end

  test "invalid" do
    {:ok, cs} = load_fixture("invalid")
    expected_errors = cs |> Enum.map(&(&1["desc"]))
    actual_errors =
      cs
      |> Enum.map(fn(c) ->
        try do
          verify(c)
        rescue
          e in RuntimeError -> e.message
        end
      end)
    assert expected_errors == actual_errors
  end

  defp generate(args) do
    Fernet.generate(args["src"], key: args["key"], iv: args["iv"],
                    now: args["now"])
  end

  defp verify(args) do
    Fernet.verify(args["token"], key: args["key"], now: args["now"])
  end

  defp load_fixture(fixture_name) do
    File.read!("fixtures/#{fixture_name}.json")
    |> JSON.decode
  end
end
