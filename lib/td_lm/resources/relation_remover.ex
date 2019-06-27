defmodule TdLm.RelationRemover do
  @moduledoc """
  This Module will be used to perform a removal of those relations which 
  business concept has been deleted
  """
  use GenServer

  alias TdCache.ConceptCache
  alias TdLm.Cache.LinkLoader
  alias TdLm.Resources

  require Logger

  @hourly 60 * 60 * 1000

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Callbacks

  @impl true
  def init(state) do
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    case ConceptCache.active_ids() do
      {:ok, active_ids} -> hard_deletion("business_concept", active_ids)
      _ -> :ok
    end

    schedule_work()
    {:noreply, state}
  end

  ## Private functions

  defp schedule_work do
    Process.send_after(self(), :work, @hourly)
  end

  defp hard_deletion(_, []), do: :ok

  defp hard_deletion(resource_type, active_ids) do
    stale_relations = Resources.list_stale_relations(resource_type, active_ids)
    stale_relations |> Enum.map(& &1.id) |> LinkLoader.delete()
    stale_relations |> Enum.each(&Resources.delete_relation/1)
  end
end
