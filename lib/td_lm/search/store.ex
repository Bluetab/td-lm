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

    cache_data = Resources.get_cache_data(relations)
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

    Tasks.log_progress(count)
    cache_data = Resources.get_cache_data(relations)

    stream_relations_map(relations, cache_data)
  end

  defp base_query(Relation = schema) do
    schema
    |> where([r], r.source_type == "business_concept")
    |> where([r], r.target_type == "data_structure")
    |> where([r], is_nil(r.deleted_at))
  end

  defp stream_relations_map(relations, cache_data) do
    Stream.map(relations, fn relation ->
      relation
      |> Map.put(
        :source_data,
        Resources.get_data(relation.source_type, relation.source_id, cache_data)
      )
      |> Map.put(
        :target_data,
        Resources.get_data(relation.target_type, relation.target_id, cache_data)
      )
    end)
  end
end
