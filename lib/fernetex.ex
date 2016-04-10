defmodule Fernet do
  @moduledoc """
  Generate or verify Fernet tokens based on https://github.com/fernet/spec

  ## Example

  Fernet generates an encrypted ciphertext from plaintext using the supplied
  256-bit key:

      iex> key = "lBrMpXneb47e_iY4RFA-HhF2vk2zeL4smfijX-y02-g="
      iex> plaintext = "Hello, world!"
      iex> {:ok, _iv, ciphertext} = Fernet.generate(plaintext, key: key)
      iex> {:ok, ^plaintext} = Fernet.verify(ciphertext, key: key)
      {:ok, "Hello, world!"}

  A TTL can optionally be supplied during decryption to reject stale messages:

      iex> key = "lBrMpXneb47e_iY4RFA-HhF2vk2zeL4smfijX-y02-g="
      iex> plaintext = "Hello, world!"
      iex> {:ok, _iv, ciphertext} = Fernet.generate(plaintext, key: key)
      iex> Fernet.verify(ciphertext, key: key, ttl: 0)
      ** (RuntimeError) expired TTL
  """

  use Timex
  use Bitwise, only_operators: true

  @max_drift 60
  @default_ttl 60
  @version 0x80

  @type key :: String.t
  @type iv :: binary
  @type plaintext :: String.t
  @type ciphertext :: String.t
  @type generate_options :: [key: key] | %{key: key}
  @type verify_options :: [key: key, ttl: integer, enforce_ttl: boolean] |
                          %{key: key, ttl: integer, enforce_ttl: boolean}

  @spec generate_key() :: key
  @doc """
  Generate a Fernet key made up of a 128-bit signing key and a 128-bit
  encryption key encoded as a base 64 string with URL and filename safe
  alphabet.
  """
  def generate_key do
    :crypto.strong_rand_bytes(32) |> encode_key
  end

  @spec generate(plaintext, generate_options) :: {:ok, iv, ciphertext}
  @doc """
  Generate a token for the given message using the key to encrypt it.

  ## Options

  The accepted options are:

    * `:key` - key to use for encryptions (256 bits, defaults to `FERNET_KEY`
               environment variable)
  """
  def generate(message, options) do
    generate(message,
             Dict.get(options, :key, default_key),
             Dict.get(options, :iv, new_iv),
             Dict.get(options, :now, formatted_now))
  end

  @spec verify(ciphertext, verify_options) :: {:ok, plaintext}
  @doc """
  Verify a token using the given key and optionally validate TTL

  ## Options

  The accepted options are:

    * `:key`         - key to use for encryptions (256 bits, defaults to
                       `FERNET_KEY` environment variable)
    * `:ttl`         - If `:enforce_ttl` is true then this is the time in
                       seconds (defaults to 60 seconds)
    * `:enforce_ttl` - Should ttl be enforced (default to true)
  """
  def verify(token, options) do
    verify(token,
           Dict.get(options, :key, default_key),
           Dict.get(options, :ttl, @default_ttl),
           Dict.get(options, :enforce_ttl, true),
           Dict.get(options, :now, formatted_now))
  end

  defp verify(token, key, ttl, enforce_ttl, now) when byte_size(key) != 32 do
    verify(token, decode_key!(key), ttl, enforce_ttl, now)
  end

  defp verify(token, key, ttl, enforce_ttl, now) when is_binary(now) do
    secs = now |> DateFormat.parse!("{ISO}") |> Date.to_secs
    verify(token, key, ttl, enforce_ttl, secs)
  end

  defp verify(token, <<sig_key :: binary-size(16), enc_key :: binary-size(16)>>, ttl, enforce_ttl, now) do
    {:ok, plain_token, message_length} = parse_token(token)
    <<version :: binary-size(1),
      issued_date :: 64-big-unsigned-integer-unit(1),
      iv :: binary-size(16),
      encrypted_message :: binary-size(message_length),
      mac :: binary-size(32)>> = plain_token
      validate_and_decrypt(version, iv, enc_key, sig_key, mac, encrypted_message, issued_date, enforce_ttl, ttl, now)
  end

  defp validate_and_decrypt(version, iv, enc_key, sig_key, mac, encrypted_message, issued_date, enforce_ttl, ttl, now) do
    if enforce_ttl do
      if ((issued_date + ttl) <= now), do: raise "expired TTL"
      if (issued_date > (now + @max_drift)), do: raise "far-future TS (unacceptable clock skew)"
    end
    payload = calculate_payload(version, issued_date, iv, encrypted_message)
    new_mac = :crypto.hmac(:sha256, sig_key, payload)
    unless mac == new_mac do
      raise "incorrect mac"
    end
    {:ok, decrypt(enc_key, encrypted_message, iv)}
  end

  defp parse_token(token) do
    try do
      plain_token = Base.url_decode64!(token)
      message_length = byte_size(plain_token) - 57
      if message_length <= 0, do: raise "too short"
      {:ok, plain_token, message_length}
    rescue
      ArgumentError -> raise "invalid base64"
    end
  end

  defp generate(message, _key, _iv, _now) when is_nil(message) or byte_size(message) == 0 do
    raise ArgumentError, "message must be provided"
  end

  defp generate(_message, key, _iv, _now) when is_nil(key) or byte_size(key) < 32 do
    raise ArgumentError, "key must be provided"
  end

  defp generate(message, key, iv, now) when byte_size(key) != 32 do
    generate(message, decode_key!(key), iv, now)
  end

  defp generate(message, key, iv, now) when is_list(iv) do
    generate(message, key, :erlang.list_to_binary(iv), now)
  end

  defp generate(message, key, iv, now) when is_binary(now) do
    secs = now |> DateFormat.parse!("{ISO}") |> Date.to_secs
    generate(message, key, iv, secs)
  end

  defp generate(message, <<sig_key :: binary-size(16), enc_key :: binary-size(16)>>, iv, now) do
    payload = calculate_payload(@version, now, iv, encrypt(enc_key, message, iv))
    mac = :crypto.hmac(:sha256, sig_key, payload)
    {:ok, iv, Base.url_encode64(payload <> mac)}
  end

  defp calculate_payload(version, now, iv, encrypted_message) do
    :erlang.list_to_binary [
      version,                   # Version
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

  defp encrypt(key, message, iv) do
    :crypto.block_encrypt(:aes_cbc128, key, iv, pad(message))
  end

  defp decrypt(_key, message, _iv) when rem(byte_size(message), 16) != 0 do
    raise "payload size not multiple of block size"
  end

  defp decrypt(key, message, iv) do
    padded_message = :crypto.block_decrypt(:aes_cbc128, key, iv, message)
    pad_len = :binary.last(padded_message)
    msg_len = byte_size(padded_message) - pad_len
    <<plain_message :: binary-size(msg_len), the_padding :: binary-size(pad_len)>> = padded_message
    unless Enum.all?(:erlang.binary_to_list(the_padding), fn (p) -> p == pad_len end), do: raise "padding error"
    plain_message
  end

  defp pad(message) do
    case rem(byte_size(message), 16) do
      0 -> message
      r -> message <> padding(16 - r)
    end
  end

  defp padding(len) do
    1..len
    |> Enum.reduce(<<>>, fn(_i, acc) ->
      acc <> <<len>>
    end)
  end

  defp encode_key(key) when byte_size(key) == 32 do
    Base.url_encode64(key)
  end

  defp decode_key!(key) when byte_size(key) == 32 do
    key
  end

  defp decode_key!(key) do
    try do
      Base.decode64!(key)
    rescue
      ArgumentError -> Base.url_decode64!(key)
    end
  end

  defp default_key, do: System.get_env("FERNET_KEY")

  defp new_iv do
    :crypto.rand_bytes 16
  end

  defp formatted_now do
    Date.now |> DateFormat.format!("{ISO}")
  end
end
