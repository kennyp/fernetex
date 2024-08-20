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
      {:error, "expired TTL"}
  """

  import Bitwise

  @max_drift 60
  @default_ttl 60
  @version 0x80

  @type key :: String.t()
  @type iv :: binary
  @type plaintext :: String.t()
  @type ciphertext :: String.t()
  @type generate_options :: [key: key] | %{key: key}
  @type verify_options ::
          [key: key, ttl: integer, enforce_ttl: boolean]
          | %{key: key, ttl: integer, enforce_ttl: boolean}

  @spec generate_key() :: key
  @doc """
  Generate a Fernet key made up of a 128-bit signing key and a 128-bit
  encryption key encoded using base64 with URL and filename safe alphabet.
  """
  def generate_key do
    32
    |> :crypto.strong_rand_bytes()
    |> encode_key
  end

  @spec generate(plaintext, generate_options) ::
          {:ok, iv, ciphertext} | {:error, String.t()}
  @doc """
  Generate a token for the given message using the key to encrypt it.

  ## Options

  The accepted options are:

    * `:key` - key to use for encryptions (256 bits, defaults to the value
               of "key" in the fernetex app config)
  """
  def generate(message, options) do
    generate(
      message,
      Keyword.get(options, :key, default_key()),
      Keyword.get(options, :iv, new_iv()),
      Keyword.get(options, :now, formatted_now())
    )
  end

  @spec generate!(plaintext, generate_options) :: {iv, ciphertext} | no_return
  def generate!(message, options) do
    case generate(message, options) do
      {:error, reason} -> raise reason
      {:ok, iv, data} -> {iv, data}
    end
  end

  @spec verify(ciphertext, verify_options) ::
          {:ok, plaintext} | {:error, String.t()}
  @doc """
  Verify a token using the given key and optionally validate TTL

  ## Options

  The accepted options are:

    * `:key`         - key to use for encryptions (256 bits, defaults to
                       the value of "key" in the fernetex app config)
    * `:ttl`         - If `:enforce_ttl` is true then this is the time in
                       seconds (defaults to 60 seconds)
    * `:enforce_ttl` - Should ttl be enforced (default to true)
  """
  def verify(token, options) do
    verify(
      token,
      Keyword.get(options, :key, default_key()),
      Keyword.get(options, :ttl, @default_ttl),
      Keyword.get(options, :enforce_ttl, true),
      Keyword.get(options, :now, formatted_now())
    )
  end

  @spec verify!(ciphertext, verify_options) :: plaintext | no_return
  def verify!(token, options) do
    case verify(token, options) do
      {:ok, result} -> result
      {:error, reason} -> raise reason
    end
  end

  defp verify(token, key, ttl, enforce_ttl, now) when byte_size(key) != 32 do
    verify(token, decode_key!(key), ttl, enforce_ttl, now)
  end

  defp verify(token, key, ttl, enforce_ttl, now) when is_binary(now) do
    {:ok, dt, _offset} = DateTime.from_iso8601(now)
    verify(token, key, ttl, enforce_ttl, DateTime.to_unix(dt))
  end

  defp verify(token, key, ttl, enforce_ttl, now) do
    token
    |> parse_token
    |> validate_and_decrypt(key, enforce_ttl, ttl, now)
  end

  defp validate_and_decrypt({:error, reason}, _, _, _, _),
    do: {:error, reason}

  defp validate_and_decrypt(
         {:ok, token, message_length},
         key,
         enforce_ttl,
         ttl,
         now
       ) do
    <<version::binary-size(1), issued_date::unsigned-big-integer-size(64)-unit(1),
      iv::binary-size(16), encrypted_message::binary-size(message_length),
      mac::binary-size(32)>> = token

    <<sig_key::binary-size(16), enc_key::binary-size(16)>> = key

    validate_and_decrypt(
      version,
      iv,
      enc_key,
      sig_key,
      mac,
      encrypted_message,
      issued_date,
      enforce_ttl,
      ttl,
      now
    )
  end

  defp validate_and_decrypt(_, _, _, _, _, _, issued_date, true, ttl, now)
       when issued_date + ttl <= now,
       do: {:error, "expired TTL"}

  defp validate_and_decrypt(_, _, _, _, _, _, issued_date, true, _, now)
       when issued_date > now + @max_drift,
       do: {:error, "far-future TS (unacceptable clock skew)"}

  defp validate_and_decrypt(
         version,
         iv,
         enc_key,
         sig_key,
         mac,
         encrypted_message,
         issued_date,
         _,
         _,
         _
       ) do
    payload = calculate_payload(version, issued_date, iv, encrypted_message)
    new_mac = :crypto.mac(:hmac, :sha256, sig_key, payload)

    if secure_compare(mac, new_mac) do
      decrypt(enc_key, encrypted_message, iv)
    else
      {:error, "incorrect mac"}
    end
  end

  @doc """
  Compares the two binaries in constant-time to avoid timing attacks.
  See: http://codahale.com/a-lesson-in-timing-attacks/

  Taken verbatim from Plug.Crypto implementation: https://github.com/elixir-plug/plug_crypto
  """
  @spec secure_compare(binary(), binary()) :: boolean()
  def secure_compare(left, right) when is_binary(left) and is_binary(right) do
    byte_size(left) == byte_size(right) and secure_compare(left, right, 0)
  end

  defp secure_compare(<<x, left::binary>>, <<y, right::binary>>, acc) do
    xorred = bxor(x, y)
    secure_compare(left, right, acc ||| xorred)
  end

  defp secure_compare(<<>>, <<>>, acc) do
    acc === 0
  end

  defp parse_token(token) do
    plain_token = Base.url_decode64!(token)
    message_length = byte_size(plain_token) - 57

    if message_length <= 0 do
      {:error, "too short"}
    else
      {:ok, plain_token, message_length}
    end
  rescue
    ArgumentError -> {:error, "invalid base64"}
  end

  defp generate(message, _key, _iv, _now)
       when is_nil(message) or byte_size(message) == 0,
       do: {:error, "message must be provided"}

  defp generate(_message, key, _iv, _now)
       when is_nil(key) or byte_size(key) < 32,
       do: {:error, "key must be provided"}

  defp generate(message, key, iv, now) when byte_size(key) != 32,
    do: generate(message, decode_key!(key), iv, now)

  defp generate(message, key, iv, now) when is_list(iv),
    do: generate(message, key, :erlang.list_to_binary(iv), now)

  defp generate(message, key, iv, now) when is_binary(now) do
    {:ok, dt, _offset} = DateTime.from_iso8601(now)
    generate(message, key, iv, DateTime.to_unix(dt))
  end

  defp generate(message, <<sig_key::binary-size(16), enc_key::binary-size(16)>>, iv, now) do
    payload = calculate_payload(@version, now, iv, encrypt(enc_key, message, iv))
    mac = :crypto.mac(:hmac, :sha256, sig_key, payload)
    {:ok, iv, Base.url_encode64(payload <> mac)}
  end

  defp calculate_payload(version, now, iv, encrypted_message) do
    :erlang.list_to_binary([
      # Version
      version,
      # Timestamp
      pack_int64_bigindian(now),
      # Initial Vector
      iv,
      # Message
      encrypted_message
    ])
  end

  defp pack_int64_bigindian(value) do
    0..7
    |> Enum.map(&(value >>> (&1 * 8) &&& 0xFF))
    |> Enum.reverse()
    |> :erlang.list_to_binary()
  end

  defp encrypt(key, message, iv),
    do: :crypto.crypto_one_time(:aes_128_cbc, key, iv, pad(message), true)

  defp decrypt(_key, message, _iv) when rem(byte_size(message), 16) != 0,
    do: {:error, "payload size not multiple of block size"}

  defp decrypt(key, message, iv) do
    padded_message = :crypto.crypto_one_time(:aes_128_cbc, key, iv, message, false)
    pad_len = :binary.last(padded_message)
    msg_len = byte_size(padded_message) - pad_len
    <<plain_message::binary-size(msg_len), the_padding::binary-size(pad_len)>> = padded_message

    correct_padding =
      the_padding
      |> :erlang.binary_to_list()
      |> Enum.all?(&(&1 == pad_len))

    if correct_padding do
      {:ok, plain_message}
    else
      {:error, "padding error"}
    end
  end

  defp pad(message) do
    message <> padding(16 - rem(byte_size(message), 16))
  end

  defp padding(len) do
    Enum.reduce(1..len, <<>>, fn _i, acc ->
      acc <> <<len>>
    end)
  end

  defp encode_key(key) when byte_size(key) == 32, do: Base.url_encode64(key)

  defp decode_key!(key) when byte_size(key) == 32, do: key

  defp decode_key!(key) do
    Base.decode64!(key)
  rescue
    ArgumentError -> Base.url_decode64!(key)
  end

  defp default_key, do: Application.get_env(:fernetex, :key)

  defp new_iv, do: :crypto.strong_rand_bytes(16)

  defp formatted_now, do: DateTime.utc_now() |> DateTime.to_iso8601(:extended)
end
