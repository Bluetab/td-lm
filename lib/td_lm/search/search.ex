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
  @accepted_wildcards ["\"", ")"]

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

    query_data = %{aggs: aggs} = fetch_query_data(%Relation{}, params)
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

  defp fetch_query_data(schema, params) do
    schema
    |> ElasticDocumentProtocol.query_data()
    |> with_search_clauses(params)
  end

  defp with_search_clauses(query_data, params) do
    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, clause_for_query(query_data, params))
  end

  def get_filter_values(%Claims{} = claims, params) do
    query_data =
      %{aggs: aggs} = fetch_query_data(%Relation{}, params)

    opts = Keyword.new(query_data)

    query =
      @permissions
      |> Permissions.filter_for_permissions(claims)
      |> Query.build_query(params, opts)

    search = %{query: query, aggs: aggs, size: 0}

    Search.get_filters(search, @index)
  end

  defp clause_for_query(query_data, %{"query" => query}) when is_binary(query) do
    if String.last(query) in @accepted_wildcards do
      strict_clause(query_data)
    else
      search_clause(query_data)
    end
  end

  defp clause_for_query(query_data, _params), do: search_clause(query_data)

  defp search_clause(%{query: %{simple: simple, as_you_type: as_you_type, exact: exact}}) do
    %{
      must: %{
        multi_match: %{type: "bool_prefix", fields: as_you_type, lenient: true}
      },
      should: [
        %{multi_match: %{type: "phrase_prefix", fields: simple, boost: 4.0, lenient: true}},
        %{simple_query_string: %{fields: exact, quote_field_suffix: ".exact", boost: 4.0}}
      ]
    }
  end

  defp search_clause(_query_data), do: %{}

  defp strict_clause(%{query: %{simple: fields}}) do
    %{must: %{simple_query_string: %{fields: fields, quote_field_suffix: ".exact"}}}
  end

  defp strict_clause(_query_data), do: %{}
end
