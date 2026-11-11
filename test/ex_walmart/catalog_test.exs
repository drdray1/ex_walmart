defmodule ExWalmart.CatalogTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Catalog, Fixtures}

  @stub __MODULE__.Stub
  @path "/api-proxy/service/affil/product/v2/paginated/items"
  @next_page @path <> "?category=976759&count=100&remainingHits=5113478"

  describe "list_catalog_items/2" do
    test "GETs /paginated/items with no params by default" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == @path
        assert conn.query_string == ""

        Req.Test.json(conn, %{
          "items" => [Fixtures.item()],
          "nextPage" => @next_page,
          "nextPageExist" => true,
          "totalPages" => 11
        })
      end)

      assert {:ok, %{"items" => [_], "nextPage" => @next_page}} =
               Catalog.list_catalog_items(Fixtures.client(@stub))
    end

    test "maps filter options to Walmart's param names" do
      Req.Test.stub(@stub, fn conn ->
        assert Fixtures.query(conn) == %{
                 "category" => "976759",
                 "brand" => "Great Value",
                 "specialOffer" => "rollback",
                 "count" => "100",
                 "soldByWmt" => "true",
                 "available" => "true",
                 "topRatedItems" => "true"
               }

        Req.Test.json(conn, %{"items" => []})
      end)

      assert {:ok, _} =
               Catalog.list_catalog_items(Fixtures.client(@stub),
                 category: "976759",
                 brand: "Great Value",
                 special_offer: "rollback",
                 count: 100,
                 sold_by_wmt: true,
                 available: true,
                 top_rated_items: true,
                 flash_deals: nil,
                 bogus: "dropped"
               )
    end
  end

  describe "next_catalog_page/2" do
    test "replays the query string of a response's nextPage" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @path

        assert Fixtures.query(conn) == %{
                 "category" => "976759",
                 "count" => "100",
                 "remainingHits" => "5113478"
               }

        Req.Test.json(conn, %{"items" => [], "nextPageExist" => false})
      end)

      assert {:ok, %{"nextPageExist" => false}} =
               Catalog.next_catalog_page(Fixtures.client(@stub), %{"nextPage" => @next_page})
    end

    test "accepts the nextPage string itself" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.query_string == "category=976759&count=100&remainingHits=5113478"
        Req.Test.json(conn, %{"items" => []})
      end)

      assert {:ok, _} = Catalog.next_catalog_page(Fixtures.client(@stub), @next_page)
    end

    test "returns :no_next_page when the response has none" do
      Req.Test.stub(@stub, fn _conn -> flunk("no request expected") end)
      client = Fixtures.client(@stub)

      assert {:error, :no_next_page} = Catalog.next_catalog_page(client, %{"items" => []})
      assert {:error, :no_next_page} = Catalog.next_catalog_page(client, %{"nextPage" => ""})
      assert {:error, :no_next_page} = Catalog.next_catalog_page(client, %{"nextPage" => nil})
    end
  end
end
