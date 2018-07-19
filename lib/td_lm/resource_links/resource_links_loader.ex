defmodule TdLm.ResourceLinksLoader do
  @moduledoc """
  GenServer to load teh links into into Redis
  """

  use GenServer

  alias TdLm.ResourceLinks
  alias TdPerms.FieldLinkCache

  require Logger

  @cache_links_on_startup Application.get_env(:td_lm, :cache_links_on_startup)

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def refresh(link_id) do
    GenServer.call(TdLm.ResourceLinksLoader, {:refresh, link_id})
  end

  def delete(field_id, resource_type, resource) do
    GenServer.call(TdLm.ResourceLinksLoader, {:delete, field_id, resource_type, resource})
  end

  @impl true
  def init(state) do
    if @cache_links_on_startup, do: schedule_work(:load_link_cache, 0)
    {:ok, state}
  end

  @impl true
  def handle_call({:refresh, link_id}, _from, state) do
    load_link(link_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, field_id, resource_type, resource}, _from, state) do
    {res, q} = FieldLinkCache.delete_resource_from_link(%{
      id: field_id,
      resource_type: resource_type,
      resource: resource
    })
    Logger.info("Deleted #{q} links with result #{res}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:load_link_cache, state) do
    load_all_links()
    {:noreply, state}
  end

  defp schedule_work(action, seconds) do
    Process.send_after(self(), action, seconds)
  end

  defp load_link(link_id) do
    link = ResourceLinks.get_resource_link!(link_id)

    [link]
    |> load_link_data()
  end

  defp load_all_links do
    ResourceLinks.list_links()
    |> load_link_data()
  end

  def load_link_data(links) do
    results =
      links
      |> Enum.map(&Map.take(&1, [:field, :resource_id, :resource_type]))
      |> Enum.map(
        &%{
          id: &1.field["field_id"],
          resource_type: "field",
          resource: %{resource_id: &1.resource_id, resource_type: &1.resource_type}
        }
      )
      |> Enum.map(&FieldLinkCache.put_field_link(&1))
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading of links failed")
    else
      Logger.info("Cached #{length(results)} links")
    end
  end
end
