# ExWalmart

Elixir client for the [Walmart Affiliate API](https://walmart.io/docs/affiliates/v1/introduction)
— search the Walmart.com catalogue, look up live price and availability, locate
stores, and build add-to-cart links (including one link for a whole basket).

Built in the same style as its sibling clients (Req + Jason, a small client
struct, `{:ok, _}` / `{:error, _}` returns, `Req.Test`-backed tests).

## Installation

```elixir
def deps do
  [
    {:ex_walmart, git: "https://github.com/drdray1/ex_walmart.git", tag: "0.1.0"}
  ]
end
```

## Usage

```elixir
client =
  ExWalmart.new(
    System.fetch_env!("WALMART_CONSUMER_ID"),
    System.fetch_env!("WALMART_PRIVATE_KEY"),
    publisher_id: System.get_env("WALMART_PUBLISHER_ID")
  )

# Find a product:
{:ok, %{"items" => [item | _]}} =
  ExWalmart.search(client, "extra virgin olive oil", num_items: 5)

# Re-check price and stock for a shopper's zip code (up to 20 ids per call):
{:ok, %{"items" => items}} =
  ExWalmart.get_items(client, [item["itemId"], 44_390_948], zip_code: "85281")

# One link that puts a whole basket in the shopper's Walmart cart:
ExWalmart.affiliate_add_to_cart_url(client, [{item["itemId"], 2}, 44_390_948])
```

Every API call returns `{:ok, body}` (the decoded JSON — a map, or a list for
stores and recommendations) or `{:error, reason}`, where `reason` is one of:

| reason | meaning |
| --- | --- |
| `{:bad_request, body}` | `400` — body is Walmart's `{"errors" => [%{"code" => 4002, "message" => ...}]}` |
| `:unauthorized` | `401`/`403` — bad consumer id, key, key version, or an expired signature |
| `:not_found` | `404` — wrong endpoint or unknown item |
| `:rate_limited` | `429` — over the rate limit |
| `{:unexpected_status, status}` | any other `>= 400` |
| `{:connection_error, reason}` | transport failure |

## Authentication

The Affiliate API has no API key or OAuth flow. You upload an RSA **public** key
to walmart.io and sign every request with the matching **private** key.

1. Create an account and an application at [walmart.io](https://walmart.io).
2. Generate a key pair:

   ```sh
   openssl genrsa -out walmart_private.pem 2048
   openssl rsa -in walmart_private.pem -pubout -out walmart_public.pem
   ```

3. Upload `walmart_public.pem` to the application. Walmart issues its
   **consumer id** and shows the **key version** (`1` for a first key).
4. Pass the consumer id and the private key to `ExWalmart.new/3`.

`ExWalmart.new/3` accepts the key as PKCS#1 or PKCS#8 PEM text, or as a bare
base64 PKCS#8 body. Literal `\n` sequences are turned back into newlines, so the
PEM can live in a single-line environment variable. A key that can't be parsed
raises `ArgumentError` — a misconfigured key fails at boot, not on first
request. The key is excluded from `inspect/1`, so a logged client never leaks it.

Each request carries `WM_CONSUMER.ID`, `WM_CONSUMER.INTIMESTAMP`,
`WM_SEC.KEY_VERSION`, and `WM_SEC.AUTH_SIGNATURE` — a SHA-256 RSA signature over
the first three values. Signatures expire after 180 seconds, so headers are
generated per request; keep the host clock in sync. See `ExWalmart.Signature`.

### Publisher id

`:publisher_id` is your Impact (Impact Radius) id from the
[Walmart affiliate program](https://affiliates.walmart.com). It is optional for
API calls — but without it the links Walmart returns carry a `|PUBID|`
placeholder instead of your id, and the `affiliate_*` link builders raise.

## Trying it in IEx

Clone the repo (or use any project that depends on `:ex_walmart`) and start a
session with the project loaded:

```sh
mix deps.get
iex -S mix
```

Build a client straight from the private key file:

```elixir
client =
  ExWalmart.new(
    "your-consumer-id",
    File.read!("walmart_private.pem"),
    publisher_id: "your-impact-id"   # optional
  )

{:ok, %{"items" => [item | _]}} = ExWalmart.search(client, "olive oil", num_items: 3)
item["name"]
item["salePrice"]

ExWalmart.get_item(client, item["itemId"], zip_code: "85281")
ExWalmart.stores_by_zip(client, "85281")
```

`{:error, :unauthorized}` usually means a wrong consumer id, a private key that
doesn't match the uploaded public key, or a key version other than `1` (pass
`key_version: "2"`).

### Environment variables

The examples in this README read credentials from the environment. Set them
before starting `iex`:

```sh
# bash / zsh
export WALMART_CONSUMER_ID="your-consumer-id"
export WALMART_PRIVATE_KEY="$(cat walmart_private.pem)"
export WALMART_PUBLISHER_ID="your-impact-id"
```

```powershell
# PowerShell
$env:WALMART_CONSUMER_ID = "your-consumer-id"
$env:WALMART_PRIVATE_KEY = Get-Content walmart_private.pem -Raw
$env:WALMART_PUBLISHER_ID = "your-impact-id"
```

Where a host only allows single-line values, replace the PEM's newlines with
literal `\n` — `ExWalmart.new/3` turns them back. Keep the private key out of
version control.

### Without credentials

The link builders make no HTTP calls, so they can be tried before you have a
walmart.io application. `ExWalmart.new/3` still needs a parseable RSA key, so
generate a throwaway one:

```elixir
key = :public_key.generate_key({:rsa, 2048, 65_537})
pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
client = ExWalmart.new("test", pem, publisher_id: "1234567")

ExWalmart.add_to_cart_url([{10_450_114, 2}, 44_390_948])
ExWalmart.affiliate_add_to_cart_url(client, [{10_450_114, 2}, 44_390_948], sub_id: "recipe-42")
```

## Options

`ExWalmart.new/3` accepts:

- `:key_version` — the version of the uploaded key (defaults to `"1"`).
- `:publisher_id` — your Impact publisher id; sent as `publisherId` on every
  request.
- `:base_url` — override the API base (defaults to
  `https://developer.api.walmart.com/api-proxy/service/affil/product/v2`).
- `:plug` — a `{Req.Test, StubName}` tuple to intercept requests in tests.

## The API

Every function takes the `client` as its first argument and returns
`{:ok, body}` / `{:error, reason}`. Options are snake_case and mapped to
Walmart's camelCase params; unknown or `nil` options are dropped.

### Search

- `ExWalmart.search/3` — `GET /search`. Options: `:category_id`, `:num_items`
  (max 25, default 10), `:start`, `:sort` (`"relevance"` | `"price"` | `"title"`
  | `"bestseller"` | `"customerRating"` | `"new"`), `:order` (`"ascending"` |
  `"descending"`, for `sort: "price"`), `:response_group` (`"base"` | `"full"`),
  `:facet` (`true`), `:facet_filter` (`"brand:Samsung"`), `:facet_range`
  (`"price:[150 TO 250]"`). Pagination stops at the top 1000 results.

### Product lookup

Real-time price and availability. Each takes `:zip_code`, `:store_id` (needs
separate approval from Walmart), `:seller_id`, `:ad_id`, `:campaign_id`.

- `ExWalmart.get_item/3` — `GET /items/{id}`. Returns the item map itself.
- `ExWalmart.get_items/3` — `GET /items?ids=...`, up to 20 ids; more returns
  `{:error, :too_many_ids}` without a request.
- `ExWalmart.get_item_by_upc/3` — `GET /items?upc=...`.
- `ExWalmart.get_item_by_gtin/3` — `GET /items?gtin=...`.

### Catalog

- `ExWalmart.list_catalog_items/2` — `GET /paginated/items`. Filters:
  `:category`, `:brand`, `:special_offer` (`"rollback"` | `"clearance"` |
  `"specialBuy"`), `:count`, `:sold_by_wmt`, `:available`, plus the boolean list
  filters documented on `ExWalmart.Catalog`.
- `ExWalmart.next_catalog_page/2` — follows a response's `"nextPage"`; returns
  `{:error, :no_next_page}` at the end.
- `ExWalmart.taxonomy/1` — `GET /taxonomy`. The category tree whose ids feed
  `:category_id` / `:category`. Large and slow-changing — cache it.

### Stores

- `ExWalmart.stores_near/3` — `GET /stores?lat=...&lon=...`.
- `ExWalmart.stores_by_zip/2` — `GET /stores?zip=...`.

### Recommendations and reviews

- `ExWalmart.recommendations/2` — `GET /nbp` ("next best product").
- `ExWalmart.post_browsed/2` — `GET /postbrowse`.
- `ExWalmart.trending/1` — `GET /trends`.
- `ExWalmart.reviews/2` — `GET /reviews/{id}`.

### Cart and affiliate links

Walmart has no cart API for affiliates; a shopper is sent to a link that drops
items into their own Walmart cart. These are pure URL builders — no HTTP.

- `ExWalmart.add_to_cart_url/1` — `https://affil.walmart.com/cart/addToCart?items=...`
  for a list of item ids and/or `{item_id, quantity}` tuples.
- `ExWalmart.affiliate_url/3` — wraps any walmart.com URL in a
  `goto.walmart.com` tracking link for the client's publisher id. Options:
  `:ad_id`, `:campaign_id`, `:sub_id` (a free-form tag, sent as `subId1`).
- `ExWalmart.affiliate_add_to_cart_url/3` — the two combined.

### Notes

For a single item, the `"affiliateAddToCartUrl"` and `"productTrackingUrl"`
Walmart returns on each item are already attributed links — use those directly.
The builders above exist for multi-item baskets.

`affiliate_url/3` mirrors the shape of the links Walmart's API returns
(including its default Impact ad id `568844` and campaign id `9383`). The
multi-item `items=ID|QTY,ID|QTY` format and `subId1` are long-standing
affiliate-program conventions rather than part of the current API reference, so
click through a generated link once with your own publisher id before relying on
it.

Item ids differ from UPCs: search and lookups return `"itemId"`, which is what
every other call and the cart links take.

## Development

```sh
mix deps.get
mix test
mix credo
mix format --check-formatted
```

## License

MIT.
