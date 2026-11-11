defmodule ExWalmart.Client do
  @moduledoc """
  Holds the connection settings for the Walmart Affiliate API — the consumer id,
  the RSA private key used to sign requests, the key version, an optional Impact
  publisher id, the base URL, and an optional `Req.Test` plug for tests.

  Build one with `ExWalmart.new/3` and pass it to every resource call:

      client = ExWalmart.new(consumer_id, System.fetch_env!("WALMART_PRIVATE_KEY"))
      ExWalmart.search(client, "olive oil")

  ## Credentials

  Create an application at [walmart.io](https://walmart.io), generate an RSA key
  pair, and upload the **public** key — Walmart then issues the application's
  consumer id. The **private** key stays with you and signs every request (see
  `ExWalmart.Signature`).

  The publisher id is your Impact (Impact Radius) id from the Walmart affiliate
  program. It is optional: with one, the `productTrackingUrl` /
  `affiliateAddToCartUrl` links Walmart returns are attributed to you; without
  one they carry a `|PUBID|` placeholder.

  The private key is kept out of `inspect/1` output so a logged client never
  leaks it.
  """

  alias ExWalmart.Signature

  @default_base_url "https://developer.api.walmart.com/api-proxy/service/affil/product/v2"

  @type t :: %__MODULE__{
          consumer_id: String.t(),
          private_key: Signature.rsa_key(),
          key_version: String.t(),
          publisher_id: String.t() | nil,
          base_url: String.t(),
          plug: term() | nil
        }

  @derive {Inspect, except: [:private_key]}
  @enforce_keys [:consumer_id, :private_key]
  defstruct consumer_id: nil,
            private_key: nil,
            key_version: "1",
            publisher_id: nil,
            base_url: @default_base_url,
            plug: nil

  @doc """
  Builds a client from a consumer id and an RSA private key.

  `private_key` is PEM text (PKCS#1 or PKCS#8) or a bare base64 PKCS#8 body; see
  `ExWalmart.Signature.parse_private_key/1`. Raises `ArgumentError` if it can't
  be parsed, so a misconfigured key fails at boot rather than on first request.

  Options:

    * `:key_version` — the version of the uploaded key (defaults to `"1"`).
    * `:publisher_id` — your Impact publisher id, added to every request as
      `publisherId` so returned links are attributed to you.
    * `:base_url` — override the API base URL (defaults to
      `#{@default_base_url}`).
    * `:plug` — a `Req.Test` stub (e.g. `{Req.Test, MyStub}`) used to intercept
      requests in tests.
  """
  @spec new(String.t(), String.t(), keyword()) :: t()
  def new(consumer_id, private_key, opts \\ []) when is_binary(consumer_id) do
    case Signature.parse_private_key(private_key) do
      {:ok, key} ->
        %__MODULE__{
          consumer_id: consumer_id,
          private_key: key,
          key_version: opts |> Keyword.get(:key_version, "1") |> to_string(),
          publisher_id: opts |> Keyword.get(:publisher_id) |> stringify(),
          base_url: Keyword.get(opts, :base_url, @default_base_url),
          plug: Keyword.get(opts, :plug)
        }

      {:error, {:invalid_private_key, detail}} ->
        raise ArgumentError, "invalid Walmart private key: #{detail}"
    end
  end

  defp stringify(nil), do: nil
  defp stringify(value), do: to_string(value)
end
