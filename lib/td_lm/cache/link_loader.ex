defmodule TdLm.Cache.LinkLoader do
  @moduledoc """
  GenServer to load link entries into shared cache.
  """

  use GenServer

  alias TdCache.ImplementationCache
  alias TdCache.LinkCache
  alias TdCache.Redix
  alias TdCache.StructureCache
  alias TdCache.TagCache
  alias TdLm.Resources

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  def check_relation_impl_id_to_impl_ref do
    GenServer.cast(__MODULE__, :check_relation_impl_id_to_impl_ref)
  end

  def refresh(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:refresh, ids})
  end

  def refresh(id) do
    GenServer.call(__MODULE__, {:refresh, [id]})
  end

  def refresh_tags do
    GenServer.call(__MODULE__, :refresh_tags)
  end

  def delete(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:delete, ids})
  end

  def delete(id) do
    GenServer.call(__MODULE__, {:delete, [id]})
  end

  def delete_tags(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:delete_tag, ids})
  end

  def delete_tag(id) do
    GenServer.call(__MODULE__, {:delete_tag, [id]})
  end

  def load do
    GenServer.cast(__MODULE__, :load)
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast(:load, state) do
    may_be_clean_cache()

    {:ok, _count} =
      %{"status" => "approved"}
      |> Resources.list_relations()
      |> load_links()

    {:ok, _count} =
      Resources.list_tags()
      |> load_links_tags()

    {:noreply, state}
  end

  def handle_cast(:refresh, state) do
    do_deprecate()
    do_activate()

    Resources.list_tags()
    |> load_links_tags()

    {:noreply, state}
  end

  def handle_cast(:check_relation_impl_id_to_impl_ref, state) do
    relations = ImplementationCache.get_relation_impl_id_and_impl_ref()

    relation_ids = Resources.migrate_impl_id_to_impl_ref(relations)

    Enum.each(relation_ids, fn id -> LinkCache.delete(id, publish: false) end)

    relation_ids
    |> Enum.map(&Resources.get_relation!/1)
    |> load_links()

    {:noreply, state}
  end

  @impl true
  def handle_call({:refresh, ids}, _from, state) do
    reply =
      ids
      |> Enum.map(&Resources.get_relation!/1)
      |> load_links()

    {:reply, reply, state}
  end

  def handle_call(:refresh_tags, _from, state) do
    Resources.list_tags()
    |> load_links_tags()

    {:reply, :ok, state}
  end

  def handle_call({:delete, ids}, _from, state) do
    reply = delete_ids(ids)
    {:reply, reply, state}
  end

  def handle_call({:delete_tag, ids}, _from, state) do
    reply = delete_tag_ids(ids)
    {:reply, reply, state}
  end

  ## Private functions

  @spec do_deprecate :: :ok
  defp do_deprecate do
    soft_deletion("data_structure")
    :ok
  rescue
    e -> Logger.error("Unexpected error while deprecateding cached structures... #{inspect(e)}")
  end

  @spec do_activate :: :ok
  defp do_activate do
    undo_deletion("data_structure")
    :ok
  rescue
    e -> Logger.error("Unexpected error while deprecateding cached structures... #{inspect(e)}")
  end

  defp undo_deletion(resource_type) do
    referenced_ids = StructureCache.referenced_ids() |> MapSet.new()
    deleted_ids = StructureCache.deleted_ids() |> MapSet.new()

    active_ids =
      referenced_ids
      |> MapSet.difference(deleted_ids)
      |> MapSet.to_list()

    {:ok, %{activated: {n, _}}} = Resources.activate(resource_type, active_ids)
    Logger.info("Activated #{n} relations")
    :ok
  end

  defp soft_deletion(resource_type) do
    deleted_ids = StructureCache.deleted_ids()

    with res <- Resources.deprecate(resource_type, deleted_ids),
         {:ok, %{deprecated: {n, _}}} when n > 0 <- res do
      Logger.info("Deprecated #{n} relations")
    else
      :ok -> :ok
      {:ok, %{deprecated: {0, _}}} -> :ok
      {:error, op, _, _} -> Logger.warning("Failed to deprecate implementations #{op}")
    end
  end

  defp load_links(links) do
    count =
      links
      |> Enum.map(&with_tags/1)
      |> Enum.map(&LinkCache.put/1)
      |> Enum.reject(&(&1 == {:ok, []}))
      |> Enum.count()

    case count do
      0 -> Logger.debug("LinkLoader: no links changed")
      1 -> Logger.info("LinkLoader: put 1 link")
      n -> Logger.info("LinkLoader: put #{n} links")
    end

    {:ok, count}
  end

  defp load_links_tags(tags) do
    count =
      tags
      |> Enum.map(&TagCache.put/1)
      |> Enum.reject(&(&1 == {:ok, []}))
      |> Enum.count()

    case count do
      0 -> Logger.debug("LinkLoader: no tag changed")
      1 -> Logger.info("LinkLoader: put 1 tag")
      n -> Logger.info("LinkLoader: put #{n} tags")
    end

    {:ok, count}
  end

  defp delete_ids(ids) do
    count =
      ids
      |> Enum.map(&LinkCache.delete/1)
      |> Enum.reject(&(&1 == {:ok, [0, 0]}))
      |> Enum.count()

    case count do
      0 -> Logger.debug("LinkLoader: no links deleted")
      1 -> Logger.info("LinkLoader: deleted 1 link")
      n -> Logger.info("LinkLoader: deleted #{n} links")
    end

    {:ok, count}
  end

  defp delete_tag_ids(ids) do
    count =
      ids
      |> Enum.map(&TagCache.delete/1)
      |> Enum.count()

    {:ok, count}
  end

  defp with_tags(%{tag_id: nil} = link), do: Map.put(link, :tags, [])

  defp with_tags(%{tag: %{value: %{"type" => type}}} = link) do
    Map.put(link, :tags, [type])
  end

  defp with_tags(link), do: Map.put(link, :tags, [])

  defp may_be_clean_cache do
    if acquire_lock?("TdLM.Cache.Migration:TD-7420") do
      response = Redix.del!(["link:keys", "link:*", "*:links", "*:links:*"])
      Logger.info("Deleted #{response} keys from migration TD-7420")
    end
  end

  defp acquire_lock?(key) do
    Redix.command!(["SET", key, node(), "NX"])
  end
end
