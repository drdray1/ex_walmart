defmodule ExWalmart.Cart do
  @moduledoc """
  Builds Walmart add-to-cart and affiliate tracking links. No HTTP — these are
  pure URL builders.

  Walmart has no cart *API* for affiliates; instead, a shopper is sent to a link
  that drops items into their own Walmart cart. For a single item the
  `"affiliateAddToCartUrl"` Walmart returns on each item is already that link.
  The functions here cover what the API doesn't hand back ready-made: **one
  link for a whole basket** (e.g. every ingredient in a recipe).

      items = [{10_450_114, 2}, 44_390_948]

      # Unattributed — fine for testing:
      ExWalmart.Cart.add_to_cart_url(items)
      #=> "https://affil.walmart.com/cart/addToCart?items=10450114%7C2,44390948"

      # Attributed to the client's publisher id:
      ExWalmart.Cart.affiliate_add_to_cart_url(client, items)
  """

  alias ExWalmart.Client

  @cart_url "https://affil.walmart.com/cart/addToCart"
  @tracking_host "https://goto.walmart.com"

  # The Impact ad / campaign ids and source id Walmart's own API puts in the
  # `productTrackingUrl` and `affiliateAddToCartUrl` it returns.
  @default_ad_id "568844"
  @default_campaign_id "9383"
  @source_id "imp_000011112222333344"

  @type item :: String.t() | integer() | {String.t() | integer(), pos_integer()}

  @doc """
  Builds a link that adds `items` to the shopper's Walmart cart.

  Each entry is an item id, or an `{item_id, quantity}` tuple. The result is
  `#{@cart_url}?items=ID|QTY,ID,...` (with `|` percent-encoded).
  """
  @spec add_to_cart_url([item()]) :: String.t()
  def add_to_cart_url([_ | _] = items) do
    @cart_url <> "?items=" <> Enum.map_join(items, ",", &encode_item/1)
  end

  @doc """
  Wraps `url` (any walmart.com URL) in an Impact tracking link attributed to the
  client's publisher id, in the same shape as the `"productTrackingUrl"`
  Walmart's API returns.

  Raises `ArgumentError` if the client has no `:publisher_id`.

  Options:

    * `:ad_id` — Impact ad id (defaults to `#{@default_ad_id}`).
    * `:campaign_id` — Impact campaign id (defaults to `#{@default_campaign_id}`).
    * `:sub_id` — a free-form tag (e.g. a recipe id) passed as Impact's
      `subId1`, so conversions can be tied back to where the click came from.
  """
  @spec affiliate_url(Client.t(), String.t(), keyword()) :: String.t()
  def affiliate_url(client, url, opts \\ [])

  def affiliate_url(%Client{publisher_id: nil}, _url, _opts) do
    raise ArgumentError, "affiliate links need a client built with a :publisher_id"
  end

  def affiliate_url(%Client{publisher_id: publisher_id}, url, opts) when is_binary(url) do
    ad_id = Keyword.get(opts, :ad_id, @default_ad_id)
    campaign_id = Keyword.get(opts, :campaign_id, @default_campaign_id)

    query =
      [{"veh", "aff"}, {"sourceid", @source_id}]
      |> maybe_append("subId1", opts[:sub_id])
      |> Kernel.++([{"u", url}])
      |> URI.encode_query()

    "#{@tracking_host}/c/#{publisher_id}/#{ad_id}/#{campaign_id}?#{query}"
  end

  @doc """
  Builds an attributed add-to-cart link for `items` —
  `add_to_cart_url/1` wrapped by `affiliate_url/3`. Takes the same options as
  `affiliate_url/3`.
  """
  @spec affiliate_add_to_cart_url(Client.t(), [item()], keyword()) :: String.t()
  def affiliate_add_to_cart_url(%Client{} = client, items, opts \\ []) do
    affiliate_url(client, add_to_cart_url(items), opts)
  end

  defp encode_item({item_id, quantity}) when is_integer(quantity) and quantity > 0,
    do: "#{item_id}%7C#{quantity}"

  defp encode_item(item_id) when is_binary(item_id) or is_integer(item_id),
    do: to_string(item_id)

  defp maybe_append(params, _key, nil), do: params
  defp maybe_append(params, key, value), do: params ++ [{key, to_string(value)}]
end
