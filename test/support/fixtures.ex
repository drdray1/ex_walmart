defmodule ExWalmart.Fixtures do
  @moduledoc """
  Test fixtures and helpers for ExWalmart.
  """

  alias ExWalmart.Signature

  @doc "A client wired to a `Req.Test` stub."
  def client(stub_name, opts \\ []) do
    ExWalmart.new(consumer_id(), private_key_pem(), [plug: {Req.Test, stub_name}] ++ opts)
  end

  @doc "The consumer id a `client/2` stub receives, for header assertions."
  def consumer_id, do: "1de0df0a-9de1-47b5-bb45-2dc8f26c5ab2"

  @doc "A throwaway RSA private key, generated once per test run."
  def private_key do
    case :persistent_term.get({__MODULE__, :key}, nil) do
      nil ->
        key = :public_key.generate_key({:rsa, 2048, 65_537})
        :persistent_term.put({__MODULE__, :key}, key)
        key

      key ->
        key
    end
  end

  @doc "The test key as a PKCS#1 PEM (`-----BEGIN RSA PRIVATE KEY-----`)."
  def private_key_pem do
    :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, private_key())])
  end

  @doc "The test key as a PKCS#8 PEM (`-----BEGIN PRIVATE KEY-----`)."
  def private_key_pkcs8_pem do
    :public_key.pem_encode([{:PrivateKeyInfo, pkcs8_der(), :not_encrypted}])
  end

  @doc "The test key as a bare base64 PKCS#8 body, as Walmart's Java sample reads it."
  def private_key_pkcs8_base64, do: Base.encode64(pkcs8_der())

  @doc "The public half of the test key."
  def public_key, do: Signature.public_key(private_key())

  @doc "A canned Walmart item."
  def item(overrides \\ %{}) do
    Map.merge(
      %{
        "itemId" => 10_450_114,
        "parentItemId" => 10_450_114,
        "name" => "Great Value Extra Virgin Olive Oil, 17 fl oz",
        "salePrice" => 5.98,
        "upc" => "078742229584",
        "categoryPath" => "Food/Pantry/Cooking Oils & Vinegar",
        "stock" => "Available",
        "availableOnline" => true,
        "affiliateAddToCartUrl" =>
          "https://goto.walmart.com/c/|PUBID|/568844/9383?veh=aff&sourceid=imp_000011112222333344" <>
            "&prodsku=10450114&u=http%3A%2F%2Faffil.walmart.com%2Fcart%2FaddToCart%3Fitems%3D10450114"
      },
      overrides
    )
  end

  @doc "A canned Walmart store."
  def store(overrides \\ %{}) do
    Map.merge(
      %{
        "no" => 2066,
        "name" => "WM Supercenter",
        "country" => "US",
        "coordinates" => [-95.511747, 29.735577],
        "streetAddress" => "2727 DUNVALE RD",
        "city" => "HOUSTON",
        "stateProvCode" => "TX",
        "zip" => "77063",
        "phoneNumber" => "007139772099"
      },
      overrides
    )
  end

  @doc "A request `Plug.Conn`'s query string, decoded to a map."
  def query(conn), do: URI.decode_query(conn.query_string)

  @doc "The value of a request header, or `nil`. Header names are matched lowercased."
  def header(conn, name) do
    conn |> Plug.Conn.get_req_header(String.downcase(name)) |> List.first()
  end

  defp pkcs8_der do
    :public_key.der_encode(:PrivateKeyInfo, private_key())
  end
end
