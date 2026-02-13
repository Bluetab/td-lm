defmodule TdLm.Search.Store do
  @moduledoc """
  Elasticsearch store for relations
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdCluster.Cluster.TdDd.Tasks
  alias TdLm.Repo
  alias TdLm.Resources
  alias TdLm.Resources.Relation

  @impl true
  def stream(Relation = schema) do
    count =
      schema
      |> base_query()
      |> Repo.aggregate(:count, :id)

    Tasks.log_start_stream(count)

    relations =
      schema
      |> base_query()
      |> Repo.stream()
      |> Repo.stream_preload(1000, :tag)

    cache_data = Resources.search_data(relations)
    Tasks.log_progress(count)
    stream_relations_map(relations, cache_data)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)

    result
  end

  def stream(Relation = schema, ids) do
    ids_query =
      schema
      |> base_query()
      |> where([r], r.id in ^ids)

    count =
      Repo.aggregate(ids_query, :count, :id)

    Tasks.log_start_stream(count)

    relations =
      ids_query
      |> Repo.stream()
      |> Repo.stream_preload(1000, :tag)

    cache_data = Resources.search_data(relations)
    Tasks.log_progress(count)
    stream_relations_map(relations, cache_data)
  end

  defp base_query(Relation = schema) do
    schema
    |> where([r], r.source_type in ["business_concept", "quality_control"])
    |> where([r], r.target_type in ["data_structure", "quality_control"])
  end

  defp stream_relations_map(relations, cache_data) do
    relations
    |> Stream.map(fn relation ->
      source_data = get_in(cache_data, [relation.source_type, relation.source_id]) || %{}
      target_data = get_in(cache_data, [relation.target_type, relation.target_id]) || %{}

      if map_size(source_data) > 0 or map_size(target_data) > 0 do
        relation
        |> Map.put(:source_data, source_data)
        |> Map.put(:target_data, target_data)
      else
        nil
      end
    end)
    |> Stream.reject(&is_nil/1)
  end
end
