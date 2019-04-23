defmodule TdLm.RelationLoader do
  @moduledoc """
  GenServer to load established relations into links in Redis
  """

  use GenServer

  alias TdLm.Resources
  alias TdPerms.RelationCache

  require Logger

  @bc_cache Application.get_env(:td_lm, :bc_cache)
  @cache_relations_on_startup Application.get_env(:td_lm, :cache_relations_on_startup)

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def refresh(relation_id) do
    GenServer.call(TdLm.RelationLoader, {:refresh, relation_id})
  end

  def delete(relation) do
    GenServer.call(TdLm.RelationLoader, {:delete, relation})
  end

  @impl true
  def init(state) do
    if @cache_relations_on_startup, do: schedule_work(:load_relation_cache, 0)
    {:ok, state}
  end

  @impl true
  def handle_call({:refresh, relation_id}, _from, state) do
    load_relation(relation_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, relation}, _from, state) do
    source =
      relation
      |> Map.take([:source_id, :source_type])
      |> load_source()

    target =
      relation
      |> Map.take([:target_id, :target_type])
      |> load_target()

    resources = build_resources(source, target)

    relation_types =
      relation
      |> Map.take([:tags])
      |> build_relation_types()

    results =
      resources
      |> RelationCache.delete_resource_from_relation(relation_types)
      |> Enum.map(fn {{r_relation, _}, {r_resource, _}} -> [r_relation, r_resource] end)
      |> List.flatten()

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Deleted failed")
    else
      Logger.info("Deleted #{length(results)} relations and resources")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:load_relation_cache, state) do
    load_all_relations()
    load_counts()
    {:noreply, state}
  end

  defp schedule_work(action, seconds) do
    Process.send_after(self(), action, seconds)
  end

  defp load_relation(relation_id) do
    relation = Resources.get_relation!(relation_id)

    [relation]
    |> load_relation_data()
  end

  defp load_all_relations do
    Resources.list_relations()
    |> load_relation_data()
  end

  defp load_relation_data(relations) do
    results =
      relations
      |> Enum.map(
        &Map.take(&1, [:target_id, :target_type, :source_id, :source_type, :context, :tags])
      )
      |> Enum.map(&load_relation_attributes(&1))
      |> Enum.map(fn {rs, r_ts} ->
        RelationCache.put_relation(rs, r_ts)
      end)
      |> List.flatten()
      |> Enum.map(fn {{r_put_relation, _}, {r_put_resource, _}} ->
        [r_put_relation, r_put_resource]
      end)
      |> List.flatten()

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading of relations failed")
    else
      Logger.info("Cached #{length(results)} relations")
    end
  end

  defp load_relation_attributes(relation) do
    source = relation |> load_source()
    target = relation |> load_target()
    context = relation |> Map.get(:context, %{})
    resources = build_resources(source, target, context)
    relation_types = build_relation_types(relation)
    {resources, relation_types}
  end

  defp load_source(%{source_id: source_id, source_type: source_type}) do
    Map.new()
    |> Map.put(:source_id, source_id)
    |> Map.put(:source_type, source_type)
  end

  defp load_target(%{target_id: target_id, target_type: target_type}) do
    Map.new()
    |> Map.put(:target_id, target_id)
    |> Map.put(:target_type, target_type)
  end

  defp build_resources(source, target, context) do
    source
    |> build_resources(target)
    |> Map.put(:context, context)
  end

  defp build_resources(source, target) do
    Map.new()
    |> Map.put(:source, source)
    |> Map.put(:target, target)
  end

  defp build_relation_types(%{tags: tags}) do
    tags
    |> Enum.map(&Map.get(&1, :value))
    |> Enum.map(&Map.get(&1, "type"))
    |> Enum.filter(&(not is_nil(&1)))
  end

  defp put_count(business_concept_id, count) do
    @bc_cache.put_field_values(business_concept_id, link_count: count)
  end

  defp load_counts do
    counts = Resources.count_relations_by_source("business_concept", "data_field")
    results =
      counts
      |> Enum.map(fn {id, count} -> put_count(id, count) end)
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading failed")
    else
      Logger.info("Cached #{length(results)} resource link counts")
    end
  end
end
