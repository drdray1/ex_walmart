defmodule ExWalmart.ClientTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Client, Fixtures}

  describe "new/3" do
    # Called with two arguments so the default-head clause is exercised
    # (delegation from `ExWalmart.new/2` calls the arity-3 clause directly).
    test "new/2 parses the key and uses the defaults" do
      client = Client.new("consumer", Fixtures.private_key_pem())

      assert %Client{consumer_id: "consumer", key_version: "1", publisher_id: nil, plug: nil} =
               client

      assert client.private_key == Fixtures.private_key()

      assert client.base_url ==
               "https://developer.api.walmart.com/api-proxy/service/affil/product/v2"
    end

    test "new/3 honors overrides, stringifying key version and publisher id" do
      client =
        Client.new("consumer", Fixtures.private_key_pem(),
          key_version: 2,
          publisher_id: 1_234_567,
          base_url: "https://example.test/v2",
          plug: {Req.Test, :stub}
        )

      assert client.key_version == "2"
      assert client.publisher_id == "1234567"
      assert client.base_url == "https://example.test/v2"
      assert client.plug == {Req.Test, :stub}
    end

    test "raises on a key that can't be parsed" do
      assert_raise ArgumentError, ~r/invalid Walmart private key/, fn ->
        Client.new("consumer", "not a key")
      end
    end
  end

  test "inspect/1 never shows the private key" do
    inspected = inspect(Client.new("consumer", Fixtures.private_key_pem()))

    assert inspected =~ "consumer"
    refute inspected =~ "private_key"
    refute inspected =~ "RSAPrivateKey"
  end
end
