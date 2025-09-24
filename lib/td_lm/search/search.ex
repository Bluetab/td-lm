defmodule TdLM.Search do
  @moduledoc """
  Search for Relations.
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdCore.Search.Query
  alias TdLm.Auth.Claims
  alias TdLm.Resources.Relation

  @default_page 0
  @default_size 20
  @index :relations
  @permissions ["manage_business_concept_links", "link_data_structure"]

  def search(%{"scroll_id" => _} = params, _claims) do
    params
    |> Map.take(["scroll", "scroll_id"])
    |> do_search(%{})
  end

  def search(params, claims) do
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @default_size)

    sort = Map.get(params, "sort", ["_score", "updated_at"])

    {query, _} = build_query(params, claims)

    do_search(%{from: page * size, size: size, query: query, sort: sort}, params)
  end

  defp do_search(search, params)

  defp do_search(%{"scroll_id" => _scroll_id} = search, _params) do
    search
    |> Search.scroll()
    |> transform_response
  end

  defp do_search(search, %{"scroll" => scroll}) do
    search
    |> Search.search(@index, params: %{"scroll" => scroll})
    |> transform_response
  end

  defp do_search(search, _params) do
    search
    |> Search.search(@index)
    |> transform_response
  end

  defp build_query(params, claims) do
    permissions_filter =
      Permissions.filter_for_permissions(
        ["manage_business_concept_links", "link_data_structure"],
        claims
      )

    query_data = %{aggs: aggs} = fetch_query_data()
    opts = Keyword.new(query_data)

    query = Query.build_query(permissions_filter, params, opts)

    {query, aggs}
  end

  defp transform_response({:ok, response}), do: transform_response(response)

  defp transform_response({:error, response}), do: %{results: response, total: 0}

  defp transform_response(%{results: results, total: total, scroll_id: scroll_id}) do
    new_results = Enum.map(results, &Map.get(&1, "_source"))
    %{results: new_results, total: total, scroll_id: scroll_id}
  end

  defp transform_response(%{results: results, total: total}) do
    new_results = Enum.map(results, &Map.get(&1, "_source"))
    %{results: new_results, total: total}
  end

  defp fetch_query_data(schema \\ %Relation{})

  defp fetch_query_data(schema) do
    schema
    |> ElasticDocumentProtocol.query_data()
    |> with_search_clauses()
  end

  defp with_search_clauses(%{fields: fields} = query_data) do
    multi_match_bool_prefix = %{
      multi_match: %{
        type: "bool_prefix",
        fields: fields,
        lenient: true,
        fuzziness: "AUTO"
      }
    }

    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, [multi_match_bool_prefix])
  end

  def get_filter_values(%Claims{} = claims, params) do
    query_data =
      %{aggs: aggs} = fetch_query_data()

    opts = Keyword.new(query_data)

    query =
      @permissions
      |> Permissions.filter_for_permissions(claims)
      |> Query.build_query(params, opts)

    search = %{query: query, aggs: aggs, size: 0}

    Search.get_filters(search, @index)
  end
end
