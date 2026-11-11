defmodule ExWalmart.SignatureTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Fixtures, Signature}

  doctest Signature

  describe "parse_private_key/1" do
    test "accepts a PKCS#1 PEM" do
      assert {:ok, key} = Signature.parse_private_key(Fixtures.private_key_pem())
      assert key == Fixtures.private_key()
    end

    test "accepts a PKCS#8 PEM" do
      assert {:ok, key} = Signature.parse_private_key(Fixtures.private_key_pkcs8_pem())
      assert key == Fixtures.private_key()
    end

    test "accepts a bare base64 PKCS#8 body" do
      assert {:ok, key} = Signature.parse_private_key(Fixtures.private_key_pkcs8_base64())
      assert key == Fixtures.private_key()
    end

    test "accepts a PEM whose newlines were flattened to literal \\n" do
      flattened = String.replace(Fixtures.private_key_pem(), "\n", "\\n")
      assert {:ok, key} = Signature.parse_private_key(flattened)
      assert key == Fixtures.private_key()
    end

    test "rejects text with no key in it" do
      assert {:error, {:invalid_private_key, _}} = Signature.parse_private_key("not a key")
      assert {:error, {:invalid_private_key, _}} = Signature.parse_private_key("")
    end

    test "rejects a PEM that isn't a private key" do
      public_pem =
        :public_key.pem_encode([
          :public_key.pem_entry_encode(:RSAPublicKey, Fixtures.public_key())
        ])

      assert {:error, {:invalid_private_key, "unsupported PEM entry :RSAPublicKey"}} =
               Signature.parse_private_key(public_pem)
    end

    test "rejects a non-RSA private key" do
      ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
      der = :public_key.der_encode(:PrivateKeyInfo, ec_key)
      pem = :public_key.pem_encode([{:PrivateKeyInfo, der, :not_encrypted}])

      assert {:error, {:invalid_private_key, "not an RSA private key"}} =
               Signature.parse_private_key(pem)
    end

    test "rejects a non-string" do
      assert {:error, {:invalid_private_key, "key must be a string"}} =
               Signature.parse_private_key(nil)
    end
  end

  describe "sign/4 and verify/5" do
    test "a signature verifies against the public key" do
      signature = Signature.sign(Fixtures.private_key(), "consumer", 1_700_000_000_000, "1")

      assert Signature.verify(
               Fixtures.public_key(),
               "consumer",
               1_700_000_000_000,
               "1",
               signature
             )
    end

    test "is a PKCS#1 v1.5 SHA-256 signature over the canonical string" do
      signature = Signature.sign(Fixtures.private_key(), "consumer", 1_700_000_000_000, "2")

      assert :public_key.verify(
               "consumer\n1700000000000\n2\n",
               :sha256,
               Base.decode64!(signature),
               Fixtures.public_key()
             )
    end

    test "verification fails when any signed value differs" do
      signature = Signature.sign(Fixtures.private_key(), "consumer", 1_700_000_000_000, "1")
      public_key = Fixtures.public_key()

      refute Signature.verify(public_key, "other", 1_700_000_000_000, "1", signature)
      refute Signature.verify(public_key, "consumer", 1_700_000_000_001, "1", signature)
      refute Signature.verify(public_key, "consumer", 1_700_000_000_000, "2", signature)
    end

    test "verification fails for a signature that isn't base64" do
      refute Signature.verify(Fixtures.public_key(), "consumer", 1, "1", "***")
    end
  end

  describe "headers/4" do
    test "builds the four Walmart headers for a given timestamp" do
      headers = Signature.headers("consumer", Fixtures.private_key(), "1", 1_700_000_000_000)

      assert [
               {"WM_CONSUMER.ID", "consumer"},
               {"WM_CONSUMER.INTIMESTAMP", "1700000000000"},
               {"WM_SEC.KEY_VERSION", "1"},
               {"WM_SEC.AUTH_SIGNATURE", signature}
             ] = headers

      assert Signature.verify(
               Fixtures.public_key(),
               "consumer",
               1_700_000_000_000,
               "1",
               signature
             )
    end

    test "defaults the timestamp to now, in milliseconds" do
      before = System.system_time(:millisecond)
      headers = Signature.headers("consumer", Fixtures.private_key(), "1")
      {_, timestamp} = List.keyfind(headers, "WM_CONSUMER.INTIMESTAMP", 0)

      assert String.to_integer(timestamp) in before..System.system_time(:millisecond)
    end
  end
end
