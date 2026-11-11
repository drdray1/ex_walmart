defmodule ExWalmart.Taxonomy do
  @moduledoc """
  The category taxonomy Walmart.com uses to organize items.
  """

  alias ExWalmart.{Client, Request}

  @doc """
  Fetches the full category tree — departments, categories, and sub-categories.

  `GET /taxonomy`. Returns `{:ok, %{"categories" => [%{"id" => ..., "name" =>
  ..., "path" => ..., "children" => [...]}]}}`. Category ids feed
  `ExWalmart.Search.search/3` (`:category_id`) and
  `ExWalmart.Catalog.list_catalog_items/2` (`:category`).

  The tree is large and changes rarely — cache it rather than fetching per
  request.
  """
  @spec taxonomy(Client.t()) :: Request.response()
  def taxonomy(%Client{} = client) do
    Request.get(client, "/taxonomy")
  end
end
