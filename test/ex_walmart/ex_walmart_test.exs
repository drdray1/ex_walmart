defmodule ExWalmartTest do
  use ExUnit.Case, async: true

  alias ExWalmart.{Client, Fixtures}

  @stub __MODULE__.Stub

  # Every facade function is called at its shortest arity, so the delegating
  # default-argument heads are exercised end to end.
  test "the facade delegates to the resource modules" do
    Req.Test.stub(@stub, fn conn ->
      body =
        case conn.request_path |> String.split("/v2/") |> List.last() do
          "stores" -> [Fixtures.store()]
          "nbp" -> [Fixtures.item()]
          "postbrowse" -> [Fixtures.item()]
          "items/1" -> Fixtures.item()
          _ -> %{"items" => [Fixtures.item()], "nextPage" => "/paginated/items?count=1"}
        end

      Req.Test.json(conn, body)
    end)

    client =
      ExWalmart.new(Fixtures.consumer_id(), Fixtures.private_key_pem(),
        plug: {Req.Test, @stub},
        publisher_id: "1234567"
      )

    assert %Client{} = client
    assert %Client{} = ExWalmart.new(Fixtures.consumer_id(), Fixtures.private_key_pem())

    assert {:ok, %{"items" => _}} = ExWalmart.search(client, "olive oil")
    assert {:ok, %{"itemId" => _}} = ExWalmart.get_item(client, 1)
    assert {:ok, %{"items" => _}} = ExWalmart.get_items(client, [1, 2])
    assert {:ok, %{"items" => _}} = ExWalmart.get_item_by_upc(client, "035000521019")
    assert {:ok, %{"items" => _}} = ExWalmart.get_item_by_gtin(client, "00039217119199")
    assert {:ok, page} = ExWalmart.list_catalog_items(client)
    assert {:ok, %{"items" => _}} = ExWalmart.next_catalog_page(client, page)
    assert {:ok, %{}} = ExWalmart.taxonomy(client)
    assert {:ok, [_]} = ExWalmart.stores_near(client, 33.4255, -111.94)
    assert {:ok, [_]} = ExWalmart.stores_by_zip(client, 85_281)
    assert {:ok, [_]} = ExWalmart.recommendations(client, 1)
    assert {:ok, [_]} = ExWalmart.post_browsed(client, 1)
    assert {:ok, %{"items" => _}} = ExWalmart.trending(client)
    assert {:ok, %{}} = ExWalmart.reviews(client, 1)

    assert ExWalmart.add_to_cart_url([1]) =~ "items=1"
    assert ExWalmart.affiliate_url(client, "https://www.walmart.com/ip/1") =~ "/c/1234567/"
    assert ExWalmart.affiliate_add_to_cart_url(client, [1]) =~ "goto.walmart.com"
  end
end
