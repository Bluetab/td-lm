defmodule TdLm.RelationRemover do
  @moduledoc """
  This Module will be used to perform a removement of those relations which 
  business concept has been deleted
  """
  use GenServer

  alias TdLm.RelationLoader
  alias TdLm.Resources
  alias TdPerms.RelationCache

  require Logger

  @business_concept_cache Application.get_env(:td_lm, :business_concept_cache)
  @relation_removement Application.get_env(:td_lm, :relation_removement)
  @relation_removement_frequency Application.get_env(:td_lm, :relation_removement_frequency)

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(state) do
    if @relation_removement, do: schedule_work()
    {:ok, state}
  end

  defp schedule_work do
    Process.send_after(self(), :work, @relation_removement_frequency)
  end

  def handle_info(:work, state) do
    existing_concept_ids = @business_concept_cache.get_existing_business_concept_set()

    Resources.list_relations()
    |> Enum.filter(&is_stale_relation?(&1, existing_concept_ids))
    |> Enum.each(&delete_relation/1)

    schedule_work()
    {:noreply, state}
  end

  defp is_stale_relation?(relation, existing_concept_ids) do
    relation.source_type === "business_concept" && relation.target_type === "data_field" &&
      !Enum.member?(existing_concept_ids, relation.source_id)
  end

  defp delete_relation(rel) do
    delete_relation_from_df(rel.target_id)
    RelationLoader.delete(rel)
    Resources.delete_relation(rel)
  end

  defp delete_relation_from_df(df_id) do
    resource_key = RelationCache.get_members(df_id, "data_field")

    resource_key
    |> Enum.each(fn res ->
      if is_bc_nil(res) do
        RelationCache.delete_element_from_set(res, "data_field:#{df_id}:relations")
      end
    end)
  end

  defp is_bc_nil(map) do
    map
    |> RelationCache.get_resources_from_key()
    |> Map.get(:business_concept_version_id) === nil
  end
end
