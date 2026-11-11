defmodule ExWalmart.Reviews do
  @moduledoc """
  Customer reviews for an item.
  """

  alias ExWalmart.{Client, Request}

  @doc """
  Fetches an item's customer reviews.

  `GET /reviews/{item_id}`. Returns `{:ok, body}` — the item's summary fields
  plus a `"reviews"` list and `"reviewStatistics"`.
  """
  @spec reviews(Client.t(), String.t() | integer()) :: Request.response()
  def reviews(%Client{} = client, item_id) do
    Request.get(client, "/reviews/#{item_id}")
  end
end
