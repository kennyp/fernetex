defmodule FernetTest do
  use ExUnit.Case
  use PropCheck

  doctest Fernet

  test "generate_key" do
    key = Fernet.generate_key()
    decoded_key = Base.url_decode64!(key)
    assert byte_size(decoded_key) == 32
  end

  test "generate" do
    cs = load_fixture("generate")
    expected_tokens = Enum.map(cs, &{:ok, :erlang.list_to_binary(&1["iv"]), &1["token"]})
    actual_tokens = Enum.map(cs, &generate/1)
    assert expected_tokens == actual_tokens
  end

  test "generate!" do
    cs = load_fixture("generate")
    expected_tokens = Enum.map(cs, &{:erlang.list_to_binary(&1["iv"]), &1["token"]})
    actual_tokens = Enum.map(cs, &generate!/1)
    assert expected_tokens == actual_tokens
  end

  test "verify" do
    cs = load_fixture("verify")
    expected_keys = Enum.map(cs, &{:ok, &1["src"]})
    actual_keys = Enum.map(cs, &verify/1)
    assert expected_keys == actual_keys
  end

  test "verify!" do
    cs = load_fixture("verify")
    expected_keys = Enum.map(cs, & &1["src"])
    actual_keys = Enum.map(cs, &verify!/1)
    assert expected_keys == actual_keys
  end

  test "invalid" do
    cs = load_fixture("invalid")
    expected_errors = Enum.map(cs, & &1["desc"])
    actual_errors = Enum.map(cs, &(&1 |> verify |> elem(1)))
    assert expected_errors == actual_errors
  end

  test "key is pulled from config" do
    msg = "Hello World!"
    iv = :crypto.strong_rand_bytes(16)
    {:ok, _iv, from_config} = Fernet.generate(msg, iv: iv)

    {:ok, _iv, passed_in} =
      Fernet.generate(msg, key: "7I2vY9OM_sAc9nu7yFRoYFngzC6I4V8560OW_53KVVQ=", iv: iv)

    assert from_config == passed_in
  end

  test "handles padding on input strings that are a len multiple of 32" do
    key = "fJXYWeIEcXMO3tLDheFVezM5QWBVFvkymG80n0Rluqs="
    msg = String.pad_trailing("hello", 32)
    {:ok, _iv, token} = Fernet.generate(msg, key: key)
    {:ok, vmsg} = Fernet.verify(token, key: key)
    assert msg == vmsg
  end

  property "can always verify what it generates" do
    key = "fJXYWeIEcXMO3tLDheFVezM5QWBVFvkymG80n0Rluqs="

    forall msg <- non_empty(utf8()) do
      {:ok, _iv, token} = Fernet.generate(msg, key: key)
      {:ok, vmsg} = Fernet.verify(token, key: key)
      assert msg == vmsg
    end
  end

  defp generate(%{"iv" => iv, "now" => now, "secret" => secret, "src" => src}),
    do: Fernet.generate(src, key: secret, iv: iv, now: now)

  defp generate!(%{"iv" => iv, "now" => now, "secret" => secret, "src" => src}),
    do: Fernet.generate!(src, key: secret, iv: iv, now: now)

  defp verify(%{"now" => now, "secret" => secret, "token" => token}),
    do: Fernet.verify(token, key: secret, now: now)

  defp verify!(%{"now" => now, "secret" => secret, "token" => token}),
    do: Fernet.verify!(token, key: secret, now: now)

  defp load_fixture(fixture_name) do
    "fixtures/#{fixture_name}.json"
    |> File.read!()
    |> Jason.decode!()
  end
end
