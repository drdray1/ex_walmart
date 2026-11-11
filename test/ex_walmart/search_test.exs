defmodule ExWalmart.SearchTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Fixtures, Search}

  @stub __MODULE__.Stub
  @base "/api-proxy/service/affil/product/v2"

  describe "search/3" do
    test "GETs /search with just the query by default" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == @base <> "/search"
        assert Fixtures.query(conn) == %{"query" => "olive oil"}

        Req.Test.json(conn, %{
          "query" => "olive oil",
          "totalResults" => 1,
          "start" => 1,
          "numItems" => 1,
          "items" => [Fixtures.item()]
        })
      end)

      assert {:ok, %{"totalResults" => 1, "items" => [%{"itemId" => 10_450_114}]}} =
               Search.search(Fixtures.client(@stub), "olive oil")
    end

    test "maps options to Walmart's param names, dropping unknown or nil ones" do
      Req.Test.stub(@stub, fn conn ->
        assert Fixtures.query(conn) == %{
                 "query" => "tv",
                 "categoryId" => "3944",
                 "start" => "11",
                 "sort" => "price",
                 "order" => "ascending",
                 "numItems" => "25",
                 "responseGroup" => "full",
                 "facet" => "on",
                 "facet.filter" => "brand:Samsung",
                 "facet.range" => "price:[150 TO 250]"
               }

        Req.Test.json(conn, %{"items" => []})
      end)

      assert {:ok, _} =
               Search.search(Fixtures.client(@stub), "tv",
                 category_id: "3944",
                 start: 11,
                 sort: "price",
                 order: "ascending",
                 num_items: 25,
                 response_group: "full",
                 facet: true,
                 facet_filter: "brand:Samsung",
                 facet_range: "price:[150 TO 250]",
                 zip_code: nil,
                 bogus: "dropped"
               )
    end

    test "leaves facets off unless facet: true" do
      Req.Test.stub(@stub, fn conn ->
        refute Map.has_key?(Fixtures.query(conn), "facet")
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} = Search.search(Fixtures.client(@stub), "tv", facet: false)
    end
  end
end
