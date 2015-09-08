defmodule Fernet do
  use Timex
  use Bitwise, only_operators: true

  def generate(args) do
    generate(
      Dict.fetch!(args, :message),
      Dict.fetch!(args, :secret),
      Dict.get(args, :iv, new_iv),
      Dict.get(args, :now, now))
  end

  defp generate(message, secret, iv, now) when is_list(iv) do
    generate(message, secret, :erlang.list_to_binary(iv), now)
  end

  defp generate(message, _secret, _iv, _now) when is_nil(message) do
    raise ArgumentError, "message must be provided"
  end

  defp generate(_message, secret, _iv, _now) when is_nil(secret) do
    raise ArgumentError, "secret must be provided"
  end

  defp generate(message, secret, iv, now) do
    key = decode_secret!(secret)
    encrypted_message = Cipher.encrypt(message, key, iv)
    {:ok, iv, encrypted_message}
  end

  defp pack_int64_bigindian(value) do
    0..7
    |> Enum.map(&((value >>> (&1 * 8)) &&& 0xff))
    |> Enum.reverse
    |> String.Chars.to_string
  end

  defp decode_secret!(secret) when byte_size(secret) == 32 do
    secret
  end

  defp decode_secret!(secret) do
    try do
      Base.decode64!(secret)
    rescue
      ArgumentError -> Base.url_decode64!(secret)
    end
  end

  defp new_iv do
    :crypto.rand_bytes 16
  end

  defp now do
    Date.now |> DateFormat.format("{ISO}")
  end
end
