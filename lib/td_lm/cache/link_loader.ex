defmodule TdLm.Cache.LinkLoader do
  @moduledoc """
  GenServer to load link entries into shared cache.
  """

  use GenServer

  alias TdCache.LinkCache
  alias TdCache.StructureCache
  alias TdLm.Resources

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  def refresh(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:refresh, ids})
  end

  def refresh(id) do
    GenServer.call(__MODULE__, {:refresh, [id]})
  end

  def delete(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:delete, ids})
  end

  def delete(id) do
    GenServer.call(__MODULE__, {:delete, [id]})
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
    {:ok, _count} =
      Resources.list_relations()
      |> load_links()

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:refresh, state) do
    do_deprecate()
    do_activate()
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

  @impl true
  def handle_call({:delete, ids}, _from, state) do
    reply = delete_ids(ids)
    {:reply, reply, state}
  end

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

  ## Private functions

  defp undo_deletion(resource_type) do
    referenced_ids = StructureCache.referenced_ids() |> MapSet.new()
    deleted_ids = StructureCache.deleted_ids() |> MapSet.new()

    active_ids =
      referenced_ids
      |> MapSet.difference(deleted_ids)
      |> MapSet.to_list()

    with res <- Resources.activate(resource_type, active_ids),
         {:ok, %{activated: {n, _}}} when n > 0 <- res do
      Logger.info("Activated #{n} relations")
    else
      :ok -> :ok
      {:ok, %{activated: {0, _}}} -> :ok
      {:error, _} -> Logger.warn("Failed to activate relations")
    end
  end

  defp soft_deletion(resource_type) do
    deleted_ids = StructureCache.deleted_ids()

    with res <- Resources.deprecate(resource_type, deleted_ids),
         {:ok, %{deprecated: {n, _}}} when n > 0 <- res do
      Logger.info("Deprecated #{n} relations")
    else
      :ok -> :ok
      {:ok, %{deprecated: {0, _}}} -> :ok
      {:error, op, _, _} -> Logger.warn("Failed to deprecate implementations #{op}")
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

  defp with_tags(%{tags: tags} = link) do
    types = Enum.flat_map(tags, &tag_types/1)
    Map.put(link, :tags, types)
  end

  defp with_tags(link) do
    Map.put(link, :tags, [])
  end

  defp tag_types(%{value: %{"type" => type}}), do: [type]
  defp tag_types(_), do: []
end
