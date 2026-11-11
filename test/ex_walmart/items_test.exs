defmodule ExWalmart.ItemsTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Fixtures, Items}

  @stub __MODULE__.Stub
  @base "/api-proxy/service/affil/product/v2"

  describe "get_item/3" do
    test "GETs /items/:id" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == @base <> "/items/10450114"
        assert conn.query_string == ""
        Req.Test.json(conn, Fixtures.item())
      end)

      assert {:ok, %{"itemId" => 10_450_114, "salePrice" => 5.98}} =
               Items.get_item(Fixtures.client(@stub), 10_450_114)
    end

    test "passes location and Impact options" do
      Req.Test.stub(@stub, fn conn ->
        assert Fixtures.query(conn) == %{
                 "zipCode" => "85281",
                 "storeId" => "3244",
                 "sellerId" => "123",
                 "adId" => "1",
                 "campaignId" => "2"
               }

        Req.Test.json(conn, Fixtures.item())
      end)

      assert {:ok, _} =
               Items.get_item(Fixtures.client(@stub), "10450114",
                 zip_code: "85281",
                 store_id: 3244,
                 seller_id: 123,
                 ad_id: 1,
                 campaign_id: 2
               )
    end
  end

  describe "get_items/3" do
    test "GETs /items with comma-joined ids" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/items"
        assert Fixtures.query(conn) == %{"ids" => "12417832,19336123", "zipCode" => "95054"}
        Req.Test.json(conn, %{"items" => [Fixtures.item(), Fixtures.item()]})
      end)

      assert {:ok, %{"items" => [_, _]}} =
               Items.get_items(Fixtures.client(@stub), [12_417_832, "19336123"],
                 zip_code: "95054"
               )
    end

    test "accepts exactly 20 ids" do
      Req.Test.stub(@stub, fn conn -> Req.Test.json(conn, %{"items" => []}) end)
      assert {:ok, _} = Items.get_items(Fixtures.client(@stub), Enum.to_list(1..20))
    end

    test "refuses more than 20 ids without making a request" do
      Req.Test.stub(@stub, fn _conn -> flunk("no request expected") end)

      assert {:error, :too_many_ids} =
               Items.get_items(Fixtures.client(@stub), Enum.to_list(1..21))
    end
  end

  describe "get_item_by_upc/3" do
    test "GETs /items with the upc" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/items"
        assert Fixtures.query(conn) == %{"upc" => "035000521019"}
        Req.Test.json(conn, %{"items" => [Fixtures.item()]})
      end)

      assert {:ok, %{"items" => [_]}} =
               Items.get_item_by_upc(Fixtures.client(@stub), "035000521019")
    end
  end

  describe "get_item_by_gtin/3" do
    test "GETs /items with the gtin and options" do
      Req.Test.stub(@stub, fn conn ->
        assert Fixtures.query(conn) == %{"gtin" => "00039217119199", "zipCode" => "95054"}
        Req.Test.json(conn, %{"items" => [Fixtures.item()]})
      end)

      assert {:ok, _} =
               Items.get_item_by_gtin(Fixtures.client(@stub), "00039217119199", zip_code: "95054")
    end
  end
end
