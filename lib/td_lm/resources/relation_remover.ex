defmodule TdLm.RelationRemover do
  @moduledoc """
  This Module will be used to perform a removal of those relations which
  business concept has been deleted
  """
  use GenServer

  require Logger

  alias TdCache.ConceptCache
  alias TdLm.Auth.Claims
  alias TdLm.Cache.LinkLoader
  alias TdLm.Resources

  @hourly 60 * 60 * 1000
  @system_claims %Claims{user_id: 0, user_name: "system"}

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Callbacks

  @impl true
  def init(state) do
    schedule_work(0)
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    case ConceptCache.active_ids() do
      {:ok, []} -> :ok
      {:ok, active_ids} -> hard_deletion("business_concept", active_ids)
      _ -> :ok
    end

    schedule_work()
    {:noreply, state}
  end

  ## Private functions

  defp schedule_work(ms \\ @hourly) do
    Process.send_after(self(), :work, ms)
  end

  defp hard_deletion(_, []), do: :ok

  defp hard_deletion(resource_type, active_ids) do
    stale_relations = Resources.list_stale_relations(resource_type, active_ids)
    stale_relations |> Enum.map(& &1.id) |> LinkLoader.delete()
    stale_relations |> Enum.each(&Resources.delete_relation(&1, @system_claims))
  end
end
