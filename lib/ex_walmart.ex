defmodule ExWalmart do
  @moduledoc """
  Elixir client for the [Walmart Affiliate API](https://walmart.io/docs/affiliates/v1/introduction)
  — search the Walmart.com catalogue, look up live price and availability,
  locate stores, and build add-to-cart links.

  ## Usage

      client =
        ExWalmart.new(
          System.fetch_env!("WALMART_CONSUMER_ID"),
          System.fetch_env!("WALMART_PRIVATE_KEY"),
          publisher_id: System.get_env("WALMART_PUBLISHER_ID")
        )

      # Find a product:
      {:ok, %{"items" => [item | _]}} =
        ExWalmart.search(client, "extra virgin olive oil", num_items: 5)

      # Re-check price and stock for a shopper's zip code:
      {:ok, %{"items" => items}} =
        ExWalmart.get_items(client, [item["itemId"], 44_390_948], zip_code: "85281")

      # One link that puts a whole basket in the shopper's Walmart cart:
      ExWalmart.affiliate_add_to_cart_url(client, [{item["itemId"], 2}, 44_390_948])

  Browse rather than search:

      {:ok, %{"categories" => categories}} = ExWalmart.taxonomy(client)
      {:ok, page} = ExWalmart.list_catalog_items(client, category: "976759", count: 100)
      {:ok, next} = ExWalmart.next_catalog_page(client, page)
      {:ok, %{"items" => trending}} = ExWalmart.trending(client)

  Around a single item:

      {:ok, item} = ExWalmart.get_item(client, 10_450_114)
      {:ok, related} = ExWalmart.recommendations(client, 10_450_114)
      {:ok, %{"reviews" => reviews}} = ExWalmart.reviews(client, 10_450_114)

  Stores:

      {:ok, stores} = ExWalmart.stores_by_zip(client, "85281")
      {:ok, stores} = ExWalmart.stores_near(client, 33.4255, -111.94)

  Every API call returns `{:ok, body}` or `{:error, reason}`, where `reason` is
  one of `{:bad_request, body}`, `:unauthorized`, `:not_found`,
  `:rate_limited`, `{:unexpected_status, status}`, or
  `{:connection_error, reason}`.

  Requests are authenticated by signing a timestamp with your RSA private key —
  see `ExWalmart.Client` for how to get credentials and `ExWalmart.Signature`
  for the scheme.
  """

  alias ExWalmart.{
    Cart,
    Catalog,
    Client,
    Items,
    Recommendations,
    Reviews,
    Search,
    Stores,
    Taxonomy
  }

  defdelegate new(consumer_id, private_key, opts \\ []), to: Client
  defdelegate search(client, query, opts \\ []), to: Search
  defdelegate get_item(client, item_id, opts \\ []), to: Items
  defdelegate get_items(client, ids, opts \\ []), to: Items
  defdelegate get_item_by_upc(client, upc, opts \\ []), to: Items
  defdelegate get_item_by_gtin(client, gtin, opts \\ []), to: Items
  defdelegate list_catalog_items(client, opts \\ []), to: Catalog
  defdelegate next_catalog_page(client, page), to: Catalog
  defdelegate taxonomy(client), to: Taxonomy
  defdelegate stores_near(client, lat, lon), to: Stores
  defdelegate stores_by_zip(client, zip), to: Stores
  defdelegate recommendations(client, item_id), to: Recommendations
  defdelegate post_browsed(client, item_id), to: Recommendations
  defdelegate trending(client), to: Recommendations
  defdelegate reviews(client, item_id), to: Reviews
  defdelegate add_to_cart_url(items), to: Cart
  defdelegate affiliate_url(client, url, opts \\ []), to: Cart
  defdelegate affiliate_add_to_cart_url(client, items, opts \\ []), to: Cart
end
