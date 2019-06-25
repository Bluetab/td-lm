defmodule TdLm.Cache.LinkLoader do
  @moduledoc """
  GenServer to load link entries into shared cache.
  """

  use GenServer
  require Logger
  alias TdCache.LinkCache
  alias TdLm.Resources

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
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

  ## Callbacks

  @impl true
  def init(state) do
    if Application.get_env(:td_lm, :env) != :test do
      Process.send_after(self(), :load, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:load, state) do
    {:ok, _count} =
      Resources.list_relations()
      |> load_links

    {:noreply, state}
  end

  @impl true
  def handle_call({:refresh, ids}, _from, state) do
    reply =
      ids
      |> Enum.map(&Resources.get_relation!/1)
      |> load_links

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:delete, ids}, _from, state) do
    reply = delete_ids(ids)
    {:reply, reply, state}
  end

  ## Private functions

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
    labels =
      tags
      |> Enum.map(&tag_label/1)

    Map.put(link, :tags, labels)
  end

  defp with_tags(link) do
    link
    |> Map.put(:tags, [])
  end

  defp tag_label(%{value: %{"label" => label}}), do: label
end
