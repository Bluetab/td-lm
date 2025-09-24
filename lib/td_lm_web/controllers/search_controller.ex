defmodule TdLmWeb.SearchController do
  use TdLmWeb, :controller

  import Canada, only: [can?: 2]

  alias TdLm.Resources.Relation
  alias TdLM.Search
  alias TdLm.Search.Indexer

  action_fallback(TdLmWeb.FallbackController)

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    %{results: results, total: total} = search_data = Search.search(params, claims)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render(:show,
      results: results,
      scroll_id: Map.get(search_data, :scroll_id)
    )
  end

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, reindex(Relation))} do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end

  def filters(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    case Search.get_filter_values(claims, params) do
      {:ok, response} -> render(conn, :show, results: response)
      {:error, _error} -> render(conn, :show, results: %{})
    end
  end
end
