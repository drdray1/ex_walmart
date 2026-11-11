defmodule ExWalmart.Search do
  @moduledoc """
  Text search over the Walmart.com catalogue.
  """

  alias ExWalmart.{Client, Request}

  @params [
    category_id: "categoryId",
    start: "start",
    sort: "sort",
    order: "order",
    num_items: "numItems",
    response_group: "responseGroup",
    facet_filter: "facet.filter",
    facet_range: "facet.range"
  ]

  @doc """
  Searches for items matching `query` that are available for sale online.

  `GET /search`. Options become query params:

    * `:category_id` — restrict to a category (an `"id"` from
      `ExWalmart.Taxonomy.taxonomy/1`, e.g. `"976759"` for Food).
    * `:num_items` — results per page, max 25 (Walmart defaults to 10).
    * `:start` — 1-based index of the first result. Pagination is limited to
      the top 1000 items for a search.
    * `:sort` — `"relevance"` (default), `"price"`, `"title"`, `"bestseller"`,
      `"customerRating"`, or `"new"`.
    * `:order` — `"ascending"` or `"descending"`; only used with `sort: "price"`.
    * `:response_group` — `"base"` (default) or `"full"`.
    * `:facet` — `true` to include facets in the response.
    * `:facet_filter` — narrow by a facet value, `"brand:Samsung"`.
    * `:facet_range` — narrow by a facet range, `"price:[150 TO 250]"`.

  Returns `{:ok, %{"query" => ..., "totalResults" => ..., "start" => ...,
  "numItems" => ..., "items" => [...]}}`. Walmart omits `"items"` when nothing
  matches.
  """
  @spec search(Client.t(), String.t(), keyword()) :: Request.response()
  def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
    params = [{"query", query}] ++ Request.query_params(opts, @params) ++ facet(opts[:facet])
    Request.get(client, "/search", params)
  end

  defp facet(true), do: [{"facet", "on"}]
  defp facet(_), do: []
end
