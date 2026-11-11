defmodule ExWalmart.Stores do
  @moduledoc """
  The Store Locator API — find nearby Walmart stores.

  Both functions return `{:ok, stores}` where `stores` is a list of maps with
  `"no"` (the store number), `"name"`, `"streetAddress"`, `"city"`,
  `"stateProvCode"`, `"zip"`, `"country"`, `"phoneNumber"`, and `"coordinates"`
  (`[lon, lat]`).
  """

  alias ExWalmart.{Client, Request}

  @doc """
  Finds the stores closest to a latitude/longitude.

  `GET /stores?lat=...&lon=...`.
  """
  @spec stores_near(Client.t(), number(), number()) :: Request.response()
  def stores_near(%Client{} = client, lat, lon) when is_number(lat) and is_number(lon) do
    Request.get(client, "/stores", [{"lat", lat}, {"lon", lon}])
  end

  @doc """
  Finds the stores in a zip code.

  `GET /stores?zip=...`.
  """
  @spec stores_by_zip(Client.t(), String.t() | integer()) :: Request.response()
  def stores_by_zip(%Client{} = client, zip) do
    Request.get(client, "/stores", [{"zip", zip}])
  end
end
