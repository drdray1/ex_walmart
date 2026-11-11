defmodule ExWalmart.Items do
  @moduledoc """
  Product lookup — real-time price and availability for known items.

  Every lookup returns Walmart's *full* item response. Price and availability
  depend on location: pass `:zip_code` to localize them, otherwise Walmart
  falls back to a default zip code (San Bruno, CA).

  Options shared by every function here:

    * `:zip_code` — zip code to check price/availability for.
    * `:store_id` — store to check price/availability for. Walmart requires
      separate business approval before honoring this.
    * `:seller_id` — only consider this seller's offer.
    * `:ad_id` / `:campaign_id` — Impact ad and campaign ids to set in the
      returned affiliate links.
  """

  alias ExWalmart.{Client, Request}

  @max_ids 20

  @params [
    zip_code: "zipCode",
    store_id: "storeId",
    seller_id: "sellerId",
    ad_id: "adId",
    campaign_id: "campaignId"
  ]

  @doc """
  Looks up a single item by Walmart item id.

  `GET /items/{item_id}`. Returns `{:ok, item}` — the item map itself, with
  `"itemId"`, `"name"`, `"salePrice"`, `"stock"`, `"affiliateAddToCartUrl"`, ….
  """
  @spec get_item(Client.t(), String.t() | integer(), keyword()) :: Request.response()
  def get_item(%Client{} = client, item_id, opts \\ []) do
    Request.get(client, "/items/#{item_id}", Request.query_params(opts, @params))
  end

  @doc """
  Looks up several items by Walmart item id in one call.

  `GET /items?ids=...`. Walmart accepts up to #{@max_ids} ids per call; more
  than that returns `{:error, :too_many_ids}` without making a request. Returns
  `{:ok, %{"items" => [...]}}` — ids Walmart can't resolve are simply absent.
  """
  @spec get_items(Client.t(), [String.t() | integer()], keyword()) :: Request.response()
  def get_items(client, ids, opts \\ [])

  def get_items(%Client{}, ids, _opts) when length(ids) > @max_ids,
    do: {:error, :too_many_ids}

  def get_items(%Client{} = client, [_ | _] = ids, opts) do
    lookup(client, {"ids", Enum.join(ids, ",")}, opts)
  end

  @doc """
  Looks up an item by UPC.

  `GET /items?upc=...`. Returns `{:ok, %{"items" => [...]}}`.
  """
  @spec get_item_by_upc(Client.t(), String.t(), keyword()) :: Request.response()
  def get_item_by_upc(%Client{} = client, upc, opts \\ []) when is_binary(upc) do
    lookup(client, {"upc", upc}, opts)
  end

  @doc """
  Looks up an item by GTIN.

  `GET /items?gtin=...`. Returns `{:ok, %{"items" => [...]}}`.
  """
  @spec get_item_by_gtin(Client.t(), String.t(), keyword()) :: Request.response()
  def get_item_by_gtin(%Client{} = client, gtin, opts \\ []) when is_binary(gtin) do
    lookup(client, {"gtin", gtin}, opts)
  end

  defp lookup(client, identifier, opts) do
    Request.get(client, "/items", [identifier | Request.query_params(opts, @params)])
  end
end
