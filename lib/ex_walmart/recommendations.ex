defmodule ExWalmart.Recommendations do
  @moduledoc """
  Walmart's recommendation feeds — related items and what's trending.
  """

  alias ExWalmart.{Client, Request}

  @doc """
  Fetches "next best product" recommendations for an item — what shoppers who
  viewed it are most likely to buy.

  `GET /nbp?itemId=...`. Returns `{:ok, items}`, a list of item maps.
  """
  @spec recommendations(Client.t(), String.t() | integer()) :: Request.response()
  def recommendations(%Client{} = client, item_id) do
    Request.get(client, "/nbp", [{"itemId", item_id}])
  end

  @doc """
  Fetches "post-browsed" recommendations for an item — what shoppers went on to
  view after it.

  `GET /postbrowse?itemId=...`. Returns `{:ok, items}`, a list of item maps.
  """
  @spec post_browsed(Client.t(), String.t() | integer()) :: Request.response()
  def post_browsed(%Client{} = client, item_id) do
    Request.get(client, "/postbrowse", [{"itemId", item_id}])
  end

  @doc """
  Fetches the items currently trending on Walmart.com.

  `GET /trends`. Returns `{:ok, %{"items" => [...]}}`.
  """
  @spec trending(Client.t()) :: Request.response()
  def trending(%Client{} = client) do
    Request.get(client, "/trends")
  end
end
