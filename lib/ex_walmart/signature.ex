defmodule ExWalmart.Signature do
  @moduledoc """
  RSA request signing for the Walmart Affiliate API.

  Every request carries four headers:

    * `WM_CONSUMER.ID` — the consumer id Walmart issues once a public key is
      uploaded for an application.
    * `WM_CONSUMER.INTIMESTAMP` — Unix time in milliseconds.
    * `WM_SEC.KEY_VERSION` — the version of the uploaded key (usually `"1"`).
    * `WM_SEC.AUTH_SIGNATURE` — base64 of the `SHA256WithRSA` (PKCS#1 v1.5)
      signature over `consumer_id <> "\\n" <> timestamp <> "\\n" <> key_version <> "\\n"`.

  The signature does not cover the URL or query string, and Walmart rejects it
  once the timestamp is more than 180 seconds old — so headers are generated
  fresh for each request.

  The private key is the RSA key whose public half was uploaded to walmart.io.
  `-----BEGIN RSA PRIVATE KEY-----` (PKCS#1) and `-----BEGIN PRIVATE KEY-----`
  (PKCS#8) PEMs are accepted, as is the bare base64 PKCS#8 body (no header
  lines) that Walmart's own Java sample reads.
  """

  @type rsa_key :: :public_key.rsa_private_key()

  @doc """
  Parses an RSA private key from PEM text or a bare base64 PKCS#8 body.

  Literal `\\n` sequences are normalised to newlines so keys pasted into an
  environment variable work unchanged.
  """
  @spec parse_private_key(String.t()) :: {:ok, rsa_key()} | {:error, term()}
  def parse_private_key(key) when is_binary(key) do
    case key |> normalize_pem() |> :public_key.pem_decode() do
      [entry | _] -> decode_entry(entry)
      [] -> {:error, {:invalid_private_key, "no PEM entry found"}}
    end
  rescue
    e -> {:error, {:invalid_private_key, Exception.message(e)}}
  end

  def parse_private_key(_), do: {:error, {:invalid_private_key, "key must be a string"}}

  @doc """
  Builds the four Walmart auth headers.

  `timestamp` (Unix milliseconds) defaults to now; pass one for deterministic
  output in tests.
  """
  @spec headers(String.t(), rsa_key(), String.t(), integer() | nil) ::
          [{String.t(), String.t()}]
  def headers(consumer_id, key, key_version, timestamp \\ nil) do
    ts = timestamp || timestamp_ms()

    [
      {"WM_CONSUMER.ID", consumer_id},
      {"WM_CONSUMER.INTIMESTAMP", Integer.to_string(ts)},
      {"WM_SEC.KEY_VERSION", key_version},
      {"WM_SEC.AUTH_SIGNATURE", sign(key, consumer_id, ts, key_version)}
    ]
  end

  @doc """
  Signs the canonical string for `consumer_id`, `timestamp`, and `key_version`
  and returns the base64-encoded signature.
  """
  @spec sign(rsa_key(), String.t(), String.t() | integer(), String.t()) :: String.t()
  def sign(key, consumer_id, timestamp, key_version) do
    consumer_id
    |> message(timestamp, key_version)
    |> :public_key.sign(:sha256, key)
    |> Base.encode64()
  end

  @doc """
  Verifies a base64 signature produced by `sign/4`. Mostly useful in tests.
  """
  @spec verify(
          :public_key.rsa_public_key(),
          String.t(),
          String.t() | integer(),
          String.t(),
          String.t()
        ) :: boolean()
  def verify(public_key, consumer_id, timestamp, key_version, signature) do
    case Base.decode64(signature) do
      {:ok, raw} ->
        consumer_id
        |> message(timestamp, key_version)
        |> :public_key.verify(:sha256, raw, public_key)

      :error ->
        false
    end
  end

  @doc """
  Returns the exact string that gets signed: the three header values in
  header-name order, each trimmed and followed by a newline.

      iex> ExWalmart.Signature.message("consumer-id", 1700000000000, "1")
      "consumer-id\\n1700000000000\\n1\\n"
  """
  @spec message(String.t(), String.t() | integer(), String.t()) :: String.t()
  def message(consumer_id, timestamp, key_version) do
    Enum.map_join([consumer_id, timestamp, key_version], &(String.trim(to_string(&1)) <> "\n"))
  end

  @doc "Current Unix time in milliseconds."
  @spec timestamp_ms() :: integer()
  def timestamp_ms, do: System.system_time(:millisecond)

  @doc "Derives the RSA public key from a private key (for verification in tests)."
  @spec public_key(rsa_key()) :: :public_key.rsa_public_key()
  def public_key(private_key) do
    {:RSAPrivateKey, _, modulus, exponent, _, _, _, _, _, _, _} = private_key
    {:RSAPublicKey, modulus, exponent}
  end

  # --- Key decoding -----------------------------------------------------------

  defp decode_entry({type, _, _} = entry) when type in [:RSAPrivateKey, :PrivateKeyInfo] do
    case :public_key.pem_entry_decode(entry) do
      {:RSAPrivateKey, _, _, _, _, _, _, _, _, _, _} = key -> {:ok, key}
      _other -> {:error, {:invalid_private_key, "not an RSA private key"}}
    end
  end

  defp decode_entry({type, _, _}) do
    {:error, {:invalid_private_key, "unsupported PEM entry #{inspect(type)}"}}
  end

  # A key with no `-----BEGIN` line is treated as a bare base64 PKCS#8 body and
  # wrapped in the matching PEM armour so one decode path handles both.
  defp normalize_pem(key) do
    key = key |> String.replace("\\n", "\n") |> String.trim()

    if String.contains?(key, "-----BEGIN") do
      key <> "\n"
    else
      "-----BEGIN PRIVATE KEY-----\n" <> key <> "\n-----END PRIVATE KEY-----\n"
    end
  end
end
