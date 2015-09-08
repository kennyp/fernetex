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

  def verify(args) do
    verify(
      Dict.fetch!(args, :token),
      Dict.fetch!(args, :secret),
      Dict.get(args, :ttl, 60),
      Dict.get(args, :enforce_ttl, true),
      Dict.get(args, :now, now))
  end

  defp verify(token, secret, ttl, enforce_ttl, now) when byte_size(secret) != 32 do
    verify(token, decode_secret!(secret), ttl, enforce_ttl, now)
  end

  defp verify(token, secret, ttl, enforce_ttl, now) when is_binary(now) do
    secs = now |> DateFormat.parse!("{ISO}") |> Date.to_secs
    verify(token, secret, ttl, enforce_ttl, secs)
  end

  defp verify(token, <<sig_key :: binary-size(16), enc_key :: binary-size(16)>>, ttl, enforce_ttl, now) do
    plain_token = Base.url_decode64!(token)
    message_length = byte_size(plain_token) - 57
    <<version :: binary-size(1),
      issued_date :: 64-big-unsigned-integer-unit(1),
      iv :: binary-size(16),
      encrypted_message :: binary-size(message_length),
      mac :: binary-size(32)>> = plain_token
    if enforce_ttl and !(((issued_date + ttl) >= now) && (issued_date < (now + 60))) do
      raise "Issued timestamp is out of range!"
    end
    payload = calculate_payload(0x80, issued_date, iv, encrypted_message)
    new_mac = :crypto.hmac(:sha256, sig_key, payload)
    unless mac == new_mac do
      raise "Signature does not match!"
    end
    {:ok, decrypt(enc_key, encrypted_message, iv)}
  end

  defp generate(message, _secret, _iv, _now) when is_nil(message) or byte_size(message) == 0 do
    raise ArgumentError, "message must be provided"
  end

  defp generate(_message, secret, _iv, _now) when is_nil(secret) or byte_size(secret) < 32 do
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
    payload = calculate_payload(0x80, now, iv, encrypt(enc_key, message, iv))
    mac = :crypto.hmac(:sha256, sig_key, payload)
    {:ok, iv, Base.url_encode64(payload <> mac)}
  end

  defp calculate_payload(version, now, iv, encrypted_message) do
    :erlang.list_to_binary [
      0x80,                      # Version
      pack_int64_bigindian(now), # Timestamp
      iv,                        # Initial Vector
      encrypted_message          # Message
    ]
  end

  defp pack_int64_bigindian(value) do
    0..7
    |> Enum.map(&((value >>> (&1 * 8)) &&& 0xff))
    |> Enum.reverse
    |> :erlang.list_to_binary
  end

  defp unpack_int64_bigindian(value) do
    value
    |> :erlang.binary_to_list
    |> Enum.reverse
    |> Enum.with_index
    |> Enum.reduce 0, fn({b,i}, acc) ->
      IO.inspect b
      IO.inspect i
      IO.inspect acc
      IO.puts "-----"
      acc ||| (b <<< (i * 8))
    end
  end

  defp encrypt(key, message, iv) do
    :crypto.block_encrypt(:aes_cbc128, key, iv, pad(message))
  end

  defp decrypt(key, message, iv) do
    :crypto.block_decrypt(:aes_cbc128, key, iv, message) |> String.rstrip ?\v
  end

  defp pad(message) do
    case rem(byte_size(message), 16) do
      0 -> message
      r -> message <> String.duplicate("\v", 16 - r)
    end
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
