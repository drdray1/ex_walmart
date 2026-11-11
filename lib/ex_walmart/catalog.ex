defmodule ExWalmart.Catalog do
  @moduledoc """
  The Catalog Product API — walk the Walmart catalogue page by page, optionally
  filtered by category, brand, or special offer.
  """

  alias ExWalmart.{Client, Request}

  @path "/paginated/items"

  @params [
    category: "category",
    brand: "brand",
    special_offer: "specialOffer",
    count: "count",
    sold_by_wmt: "soldByWmt",
    available: "available",
    flash_deals: "flashDeals",
    extra_savings: "extraSavings",
    annual_event: "annualEvent",
    pre_owned: "preOwned",
    collectibles: "collectibles",
    top_rated_items: "topRatedItems",
    fulfilled_by_walmart: "fulfilledByWalmart",
    pro_seller_items: "proSellerItems",
    limited_time_deals: "limitedTimeDeals",
    marketplace_collection: "marketplaceCollection",
    daily_deal_items: "dailyDealItems",
    ad_id: "adId",
    campaign_id: "campaignId"
  ]

  @doc """
  Fetches the first page of catalogue items.

  `GET /paginated/items`. Walmart recommends passing `:category` or `:brand`
  for faster responses. Options:

    * `:category` — a category `"id"` from `ExWalmart.Taxonomy.taxonomy/1`.
    * `:brand` — brand name.
    * `:special_offer` — `"rollback"`, `"clearance"`, or `"specialBuy"`.
    * `:count` — number of items per page.
    * `:sold_by_wmt` — `true` to exclude marketplace items.
    * `:available` — `true` to exclude out-of-stock items.
    * boolean list filters, each `true` to restrict to that list:
      `:flash_deals`, `:extra_savings`, `:annual_event`, `:pre_owned`,
      `:collectibles`, `:top_rated_items`, `:fulfilled_by_walmart`,
      `:pro_seller_items`, `:limited_time_deals`, `:marketplace_collection`,
      `:daily_deal_items`.
    * `:ad_id` / `:campaign_id` — Impact ids to set in the affiliate links.

  Returns `{:ok, %{"items" => [...], "nextPage" => "...", "nextPageExist" =>
  ..., "totalPages" => ...}}`. Pass the response to `next_catalog_page/2` to
  continue.
  """
  @spec list_catalog_items(Client.t(), keyword()) :: Request.response()
  def list_catalog_items(%Client{} = client, opts \\ []) do
    Request.get(client, @path, Request.query_params(opts, @params))
  end

  @doc """
  Fetches the page after `page`.

  `page` is a previous response map (its `"nextPage"` is followed) or the
  `"nextPage"` string itself. Returns `{:error, :no_next_page}` when the
  response has no further page.
  """
  @spec next_catalog_page(Client.t(), map() | String.t()) :: Request.response()
  def next_catalog_page(%Client{} = client, %{"nextPage" => next_page})
      when is_binary(next_page) and next_page != "",
      do: next_catalog_page(client, next_page)

  def next_catalog_page(%Client{}, %{}), do: {:error, :no_next_page}

  # `nextPage` is a host-relative URL back to this same endpoint; only its
  # query string (cursor + the original filters) needs replaying.
  def next_catalog_page(%Client{} = client, next_page) when is_binary(next_page) do
    params =
      (URI.parse(next_page).query || "")
      |> URI.query_decoder()
      |> Enum.to_list()

    Request.get(client, @path, params)
  end
end
