defmodule TdLm.RelationLoader do
  @moduledoc """
  GenServer to load established relations into links in Redis
  """

  use GenServer

  alias TdLm.Resources
  alias TdPerms.RelationCache

  require Logger

  @business_concept_cache Application.get_env(:td_lm, :business_concept_cache)

  def start_link(config, name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, config, name: name)
  end

  def refresh(relation_id) do
    GenServer.call(__MODULE__, {:refresh, relation_id})
  end

  def delete(relation) do
    GenServer.call(__MODULE__, {:delete, relation})
  end

  def ping do
    GenServer.call(__MODULE__, :ping)
  end

  def load do
    GenServer.cast(__MODULE__, :load_cache)
  end

  @impl true
  def init(state) do
    if Keyword.get(state, :load_on_startup, false) do
      Process.send_after(self(), :load_on_startup, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:load_on_startup, state) do
    load_cache()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:load_cache, state) do
    load_cache()
    {:noreply, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
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

  defp load_cache do
    load_all_relations()
    load_counts()

    check_legacy_bc_parent_relations()
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
    @business_concept_cache.put_field_values(business_concept_id, link_count: count)
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

  defp check_legacy_bc_parent_relations do
    %{id: tag_id} = get_or_create_parent_tag()

    bc_parents =
      @business_concept_cache.get_bc_parents!()
      |> Enum.filter(&(not exist_bc_relation_with_tag?(&1, tag_id)))

    bc_attrs = build_bc_attrs_map(bc_parents)

    bc_parents
    |> Enum.map(fn {id, parent_id} ->
      source = Map.get(bc_attrs, parent_id)
      target = Map.get(bc_attrs, id)

      %{
        source_id: parent_id,
        source_type: "business_concept",
        target_id: id,
        target_type: "business_concept",
        context: %{
          source: source,
          target: target
        }
      }
    end)
    |> Enum.map(&Map.put(&1, :tag_ids, [tag_id]))
    |> Enum.map(&Resources.create_relation/1)
  end

  defp build_bc_attrs_map(bc_parents) do
    fields = [
      "business_concept_version_id",
      "name",
      "current_version"
    ]

    bc_parents
    |> Enum.flat_map(fn {id, parent_id} -> [id, parent_id] end)
    |> Enum.uniq()
    |> Enum.map(fn id ->
      {:ok, bc_attrs} = @business_concept_cache.get_field_values(id, fields)

      {id,
       %{
         id: Map.get(bc_attrs, "business_concept_version_id"),
         name: Map.get(bc_attrs, "name"),
         version: Map.get(bc_attrs, "current_version"),
         business_concept_id: id
       }}
    end)
    |> Map.new()
  end

  defp get_or_create_parent_tag do
    tag_value = %{
      target_type: "business_concept",
      type: "bc_parent"
    }

    tag =
      %{value: tag_value}
      |> Resources.list_tags()
      |> Enum.at(0)

    case tag do
      nil ->
        value =
          tag_value
          |> Map.put(:label, "padre de")

        {:ok, t} = Resources.create_tag(%{value: value})
        t

      t ->
        t
    end
  end

  defp exist_bc_relation_with_tag?({target_id, source_id}, tag_id) do
    relation_filter = %{
      source_id: source_id,
      source_type: "business_concept",
      target_id: target_id,
      target_type: "business_concept"
    }

    relation_filter
    |> Resources.list_relations()
    |> Enum.flat_map(&Map.get(&1, :tags, []))
    |> Enum.map(&Map.get(&1, :id))
    |> Enum.member?(tag_id)
  end
end
