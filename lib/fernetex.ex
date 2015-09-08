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

  defp generate(message, _secret, _iv, _now) when is_nil(message) or byte_size(message) == 0 do
    raise ArgumentError, "message must be provided"
  end

  defp generate(_message, secret, _iv, _now) when is_nil(secret) do
    raise ArgumentError, "secret must be provided"
  end

  defp generate(message, secret, iv, now) when byte_size(secret) != 32 do
    generate(message, decode_secret!(secret), iv, now)
  end

  defp generate(message, secret, iv, now) when is_list(iv) do
    generate(message, secret, :erlang.list_to_binary(iv), now)
  end

  defp generate(message, secret, iv, now) when is_binary(now) do
    secs = now |> DateFormat.parse!("{ISO}") |> Date.to_secs
    generate(message, secret, iv, secs)
  end

  defp generate(message, <<sig_key :: binary-size(16), enc_key :: binary-size(16)>>, iv, now) do
    payload = :erlang.list_to_binary [
      0x80,                         # Version
      pack_int64_bigindian(now),    # Timestamp
      iv,                           # Initial Vector
      encrypt(enc_key, message, iv) # Message
    ]
    mac = :crypto.hmac(:sha256, sig_key, payload)
    {:ok, iv, Base.url_encode64(payload <> mac)}
  end

  defp pack_int64_bigindian(value) do
    0..7
    |> Enum.map(&((value >>> (&1 * 8)) &&& 0xff))
    |> Enum.reverse
    |> :erlang.list_to_binary
  end

  defp encrypt(key, message, iv) do
    :crypto.block_encrypt(:aes_cbc128, key, iv, pad(message))
  end

  defp pad(message) do
    case rem(byte_size(message), 16) do
      0 -> message
      r -> message <> padding(15 - r)
    end
  end

  defp padding(len) do
    0..len |> Enum.map(fn(i) -> ?\v end) |> :erlang.list_to_binary
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
    Date.now |> DateFormat.format!("{ISO}")
  end
end
