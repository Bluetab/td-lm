defmodule TdLmWeb.SearchController do
  use TdLmWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCache.I18nCache
  alias TdLm.Resources.Relation
  alias TdLM.Search
  alias TdLm.Search.Indexer

  action_fallback(TdLmWeb.FallbackController)

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]
    locale = conn.assigns[:locale]

    %{results: results, total: total} =
      search_data =
      params
      |> sort_params(locale)
      |> Search.search(claims)

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
      {:ok, response} -> render(conn, :show, filters: response)
      {:error, _error} -> render(conn, :show, filters: %{})
    end
  end

  defp sort_params(%{"sort" => sort} = params, locale) when is_map(sort) do
    {:ok, default_locale} = I18nCache.get_default_locale()
    active_locales = I18nCache.get_active_locales!()

    cond do
      locale == default_locale ->
        params

      locale in active_locales ->
        update_sort_with_locale(params, locale)

      true ->
        params
    end
  end

  defp sort_params(params, _locale), do: params

  defp update_sort_with_locale(params, locale) do
    Map.update!(params, "sort", fn sort ->
      Map.new(sort, fn
        {"source_name.raw", value} ->
          {"source_name_#{locale}.raw", value}

        {"target_name.raw", value} ->
          {"target_name_#{locale}.raw", value}

        default ->
          default
      end)
    end)
  end
end
