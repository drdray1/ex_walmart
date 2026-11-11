defmodule ExWalmart.RequestTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Fixtures, Request, Signature}

  @stub __MODULE__.Stub

  describe "get/3" do
    test "sends a signed GET under the base URL path" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.host == "developer.api.walmart.com"
        assert conn.request_path == "/api-proxy/service/affil/product/v2/taxonomy"
        assert Fixtures.header(conn, "accept") == "application/json"

        consumer_id = Fixtures.header(conn, "WM_CONSUMER.ID")
        timestamp = Fixtures.header(conn, "WM_CONSUMER.INTIMESTAMP")
        key_version = Fixtures.header(conn, "WM_SEC.KEY_VERSION")
        signature = Fixtures.header(conn, "WM_SEC.AUTH_SIGNATURE")

        assert consumer_id == Fixtures.consumer_id()
        assert key_version == "3"
        assert_in_delta String.to_integer(timestamp), System.system_time(:millisecond), 5_000

        assert Signature.verify(
                 Fixtures.public_key(),
                 consumer_id,
                 timestamp,
                 key_version,
                 signature
               )

        Req.Test.json(conn, %{"ok" => true})
      end)

      assert {:ok, %{"ok" => true}} =
               Request.get(Fixtures.client(@stub, key_version: "3"), "/taxonomy")
    end

    test "sends no publisherId when the client has none" do
      Req.Test.stub(@stub, fn conn ->
        assert Fixtures.query(conn) == %{"query" => "milk"}
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} = Request.get(Fixtures.client(@stub), "/search", [{"query", "milk"}])
    end

    test "adds the client's publisherId to every request" do
      Req.Test.stub(@stub, fn conn ->
        assert Fixtures.query(conn) == %{"publisherId" => "777", "query" => "milk"}
        Req.Test.json(conn, %{})
      end)

      client = Fixtures.client(@stub, publisher_id: "777")
      assert {:ok, _} = Request.get(client, "/search", [{"query", "milk"}])
    end

    test "an explicit publisherId param wins over the client's" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.query_string == "publisherId=999"
        Req.Test.json(conn, %{})
      end)

      client = Fixtures.client(@stub, publisher_id: "777")
      assert {:ok, _} = Request.get(client, "/search", [{"publisherId", "999"}])
    end
  end

  describe "query_params/2" do
    test "renames allowed options and drops nil or unknown ones" do
      assert Request.query_params(
               [num_items: 5, zip_code: "85281", start: nil, bogus: "dropped"],
               num_items: "numItems",
               start: "start",
               zip_code: "zipCode"
             ) == [{"numItems", 5}, {"zipCode", "85281"}]
    end
  end

  describe "handle_response via get/3" do
    test "a 2xx returns {:ok, body} for maps and lists" do
      Req.Test.stub(@stub, fn conn -> Req.Test.json(conn, [%{"no" => 1}]) end)
      assert {:ok, [%{"no" => 1}]} = Request.get(Fixtures.client(@stub), "/stores")
    end

    test "an empty successful body returns {:ok, %{}}" do
      Req.Test.stub(@stub, fn conn -> Plug.Conn.send_resp(conn, 200, "") end)
      assert {:ok, %{}} = Request.get(Fixtures.client(@stub), "/x")
    end

    test "400 maps to {:bad_request, body} carrying Walmart's error codes" do
      body = %{"errors" => [%{"message" => "Invalid itemId", "code" => 4002}]}

      Req.Test.stub(@stub, fn conn ->
        conn |> Plug.Conn.put_status(400) |> Req.Test.json(body)
      end)

      assert {:error, {:bad_request, ^body}} = Request.get(Fixtures.client(@stub), "/items/x")
    end

    test "401 and 403 map to :unauthorized" do
      for status <- [401, 403] do
        Req.Test.stub(@stub, fn conn -> Plug.Conn.send_resp(conn, status, "") end)
        assert {:error, :unauthorized} = Request.get(Fixtures.client(@stub), "/x")
      end
    end

    test "404 maps to :not_found" do
      Req.Test.stub(@stub, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)
      assert {:error, :not_found} = Request.get(Fixtures.client(@stub), "/x")
    end

    test "429 maps to :rate_limited" do
      Req.Test.stub(@stub, fn conn -> Plug.Conn.send_resp(conn, 429, "") end)
      assert {:error, :rate_limited} = Request.get(Fixtures.client(@stub), "/x")
    end

    test "other >= 400 maps to {:unexpected_status, status}" do
      Req.Test.stub(@stub, fn conn -> Plug.Conn.send_resp(conn, 503, "") end)
      assert {:error, {:unexpected_status, 503}} = Request.get(Fixtures.client(@stub), "/x")
    end

    test "a transport error maps to {:connection_error, reason}" do
      Req.Test.stub(@stub, fn conn -> Req.Test.transport_error(conn, :econnrefused) end)

      assert {:error, {:connection_error, %Req.TransportError{reason: :econnrefused}}} =
               Request.get(Fixtures.client(@stub), "/x")
    end
  end
end
