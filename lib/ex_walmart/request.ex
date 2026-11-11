defmodule ExWalmart.Request do
  @moduledoc """
  Low-level HTTP for an `ExWalmart.Client`.

  Every request is a signed `GET` (see `ExWalmart.Signature`) against the
  client's `base_url`, carries the client's `publisherId` when it has one, and
  is normalized to `{:ok, body}` / `{:error, reason}` by `handle_response/1`.
  Transient errors and `429`s are retried with exponential backoff in the real
  client and disabled under a test plug so stubbed responses return
  deterministically.
  """

  alias ExWalmart.{Client, Signature}

  @type response :: {:ok, map() | list()} | {:error, term()}

  @doc """
  Builds Walmart query params from `opts`.

  `allowed` maps option keys to Walmart's parameter names, e.g.
  `[num_items: "numItems"]`. Options that are absent or `nil` are dropped, as
  are options not in `allowed`.
  """
  @spec query_params(keyword(), [{atom(), String.t()}]) :: [{String.t(), term()}]
  def query_params(opts, allowed) do
    for {key, name} <- allowed, value = opts[key], value != nil, do: {name, value}
  end

  @doc """
  Performs a signed `GET` against `path` (relative to the client `base_url`)
  with `params` as the query string, and normalizes the response.
  """
  @spec get(Client.t(), String.t(), [{String.t(), term()}]) :: response()
  def get(%Client{} = client, path, params \\ []) do
    [
      method: :get,
      base_url: client.base_url,
      url: path,
      headers: headers(client),
      params: with_publisher(params, client.publisher_id)
    ]
    |> Keyword.merge(retry_opts(client.plug))
    |> maybe_plug(client.plug)
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Normalizes a Walmart API response to `{:ok, body}` or `{:error, reason}`.

  Walmart reports problems as `{"errors": [{"code": 4002, "message": ...}]}`;
  for a `400` that body is returned in `{:bad_request, body}` so callers can
  match on Walmart's internal error code.
  """
  @spec handle_response({:ok, Req.Response.t()} | {:error, term()}) :: response()
  def handle_response({:ok, %Req.Response{status: status, body: body}})
      when status in 200..299,
      do: {:ok, normalize_body(body)}

  def handle_response({:ok, %Req.Response{status: 400, body: body}}),
    do: {:error, {:bad_request, body}}

  def handle_response({:ok, %Req.Response{status: status}}) when status in [401, 403],
    do: {:error, :unauthorized}

  def handle_response({:ok, %Req.Response{status: 404}}), do: {:error, :not_found}

  def handle_response({:ok, %Req.Response{status: 429}}), do: {:error, :rate_limited}

  def handle_response({:ok, %Req.Response{status: status}}) when status >= 400,
    do: {:error, {:unexpected_status, status}}

  def handle_response({:error, reason}), do: {:error, {:connection_error, reason}}

  defp normalize_body(body) when body in ["", nil], do: %{}
  defp normalize_body(body), do: body

  # --- Headers / params -------------------------------------------------------

  defp headers(%Client{} = client) do
    [{"accept", "application/json"}] ++
      Signature.headers(client.consumer_id, client.private_key, client.key_version)
  end

  # An explicit publisherId in `params` (e.g. replayed from a `nextPage` URL)
  # wins over the client's.
  defp with_publisher(params, nil), do: params

  defp with_publisher(params, publisher_id) do
    if List.keymember?(params, "publisherId", 0) do
      params
    else
      [{"publisherId", publisher_id} | params]
    end
  end

  # Retry transient errors / 429s in the real client; disable under a test plug
  # so stubbed error responses return immediately and deterministically.
  defp retry_opts(nil),
    do: [retry: :transient, max_retries: 3, retry_delay: &retry_delay/1]

  defp retry_opts(_plug), do: [retry: false]

  # Exponential backoff for transient errors / 429s.
  defp retry_delay(attempt), do: 500 * Integer.pow(2, attempt)

  defp maybe_plug(opts, nil), do: opts
  defp maybe_plug(opts, plug), do: Keyword.put(opts, :plug, plug)
end
