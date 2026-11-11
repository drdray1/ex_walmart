defmodule ExWalmart.EndpointsTest do
  @moduledoc "Taxonomy, stores, recommendations, and reviews — the parameter-light endpoints."
  use ExUnit.Case, async: true

  alias ExWalmart.{Fixtures, Recommendations, Reviews, Stores, Taxonomy}

  @stub __MODULE__.Stub
  @base "/api-proxy/service/affil/product/v2"

  describe "Taxonomy.taxonomy/1" do
    test "GETs /taxonomy" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == @base <> "/taxonomy"
        assert conn.query_string == ""

        Req.Test.json(conn, %{
          "categories" => [%{"id" => "976759", "name" => "Food", "path" => "Food"}]
        })
      end)

      assert {:ok, %{"categories" => [%{"id" => "976759"}]}} =
               Taxonomy.taxonomy(Fixtures.client(@stub))
    end
  end

  describe "Stores" do
    test "stores_near/3 GETs /stores with lat and lon" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/stores"
        assert Fixtures.query(conn) == %{"lat" => "29.735577", "lon" => "-95.511747"}
        Req.Test.json(conn, [Fixtures.store()])
      end)

      assert {:ok, [%{"no" => 2066}]} =
               Stores.stores_near(Fixtures.client(@stub), 29.735577, -95.511747)
    end

    test "stores_by_zip/2 GETs /stores with the zip" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/stores"
        assert Fixtures.query(conn) == %{"zip" => "77063"}
        Req.Test.json(conn, [Fixtures.store()])
      end)

      assert {:ok, [%{"zip" => "77063"}]} = Stores.stores_by_zip(Fixtures.client(@stub), "77063")
    end
  end

  describe "Recommendations" do
    test "recommendations/2 GETs /nbp with the item id" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/nbp"
        assert Fixtures.query(conn) == %{"itemId" => "10450114"}
        Req.Test.json(conn, [Fixtures.item(%{"itemId" => 2})])
      end)

      assert {:ok, [%{"itemId" => 2}]} =
               Recommendations.recommendations(Fixtures.client(@stub), 10_450_114)
    end

    test "post_browsed/2 GETs /postbrowse with the item id" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/postbrowse"
        assert Fixtures.query(conn) == %{"itemId" => "10450114"}
        Req.Test.json(conn, [Fixtures.item(%{"itemId" => 3})])
      end)

      assert {:ok, [%{"itemId" => 3}]} =
               Recommendations.post_browsed(Fixtures.client(@stub), "10450114")
    end

    test "trending/1 GETs /trends" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/trends"
        assert conn.query_string == ""
        Req.Test.json(conn, %{"items" => [Fixtures.item()]})
      end)

      assert {:ok, %{"items" => [_]}} = Recommendations.trending(Fixtures.client(@stub))
    end
  end

  describe "Reviews.reviews/2" do
    test "GETs /reviews/:id" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == @base <> "/reviews/10450114"
        assert conn.query_string == ""
        Req.Test.json(conn, %{"itemId" => 10_450_114, "reviews" => [%{"title" => "Great"}]})
      end)

      assert {:ok, %{"reviews" => [%{"title" => "Great"}]}} =
               Reviews.reviews(Fixtures.client(@stub), 10_450_114)
    end
  end
end
