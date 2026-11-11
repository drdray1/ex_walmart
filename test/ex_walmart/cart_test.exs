defmodule ExWalmart.CartTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Cart, Fixtures}

  @cart "https://affil.walmart.com/cart/addToCart"

  defp client(opts \\ [publisher_id: "1234567"]), do: Fixtures.client(:unused, opts)

  describe "add_to_cart_url/1" do
    test "a single item id" do
      assert Cart.add_to_cart_url([516_833_054]) == @cart <> "?items=516833054"
    end

    test "mixes bare ids and {id, quantity} tuples" do
      assert Cart.add_to_cart_url([{10_450_114, 2}, "44390948", {"638", 1}]) ==
               @cart <> "?items=10450114%7C2,44390948,638%7C1"
    end

    test "decodes back to Walmart's ID|QTY format" do
      %URI{query: query} = URI.parse(Cart.add_to_cart_url([{10_450_114, 2}, 44_390_948]))
      assert URI.decode_query(query) == %{"items" => "10450114|2,44390948"}
    end

    test "rejects a non-positive quantity" do
      assert_raise FunctionClauseError, fn -> Cart.add_to_cart_url([{1, 0}]) end
    end
  end

  describe "affiliate_url/3" do
    test "wraps a URL in a goto.walmart.com tracking link, like the API's own links" do
      url = Cart.affiliate_url(client(), "https://www.walmart.com/ip/516833054")

      assert url ==
               "https://goto.walmart.com/c/1234567/568844/9383?veh=aff" <>
                 "&sourceid=imp_000011112222333344" <>
                 "&u=https%3A%2F%2Fwww.walmart.com%2Fip%2F516833054"
    end

    test "honors :ad_id, :campaign_id and :sub_id" do
      uri =
        client()
        |> Cart.affiliate_url("https://www.walmart.com/ip/1",
          ad_id: 11,
          campaign_id: 22,
          sub_id: "recipe-42"
        )
        |> URI.parse()

      assert uri.path == "/c/1234567/11/22"

      assert URI.decode_query(uri.query) == %{
               "veh" => "aff",
               "sourceid" => "imp_000011112222333344",
               "subId1" => "recipe-42",
               "u" => "https://www.walmart.com/ip/1"
             }
    end

    test "raises without a publisher id" do
      assert_raise ArgumentError, ~r/publisher_id/, fn ->
        Cart.affiliate_url(client([]), "https://www.walmart.com/ip/1")
      end
    end
  end

  describe "affiliate_add_to_cart_url/3" do
    test "wraps the basket link, which survives the round trip intact" do
      items = [{10_450_114, 2}, 44_390_948]
      uri = client() |> Cart.affiliate_add_to_cart_url(items) |> URI.parse()

      assert uri.host == "goto.walmart.com"
      assert URI.decode_query(uri.query)["u"] == Cart.add_to_cart_url(items)
    end

    test "passes options through" do
      url = Cart.affiliate_add_to_cart_url(client(), [1], sub_id: "r1")
      assert url =~ "subId1=r1"
    end
  end
end
