defmodule TdLm.RelationRemover do
  @moduledoc """
  This Module will be used to perform a removement of those relations which 
  business concept has been deleted
  """
  use GenServer

  alias TdLm.RelationLoader
  alias TdLm.Resources
  alias TdPerms.BusinessConceptCache
  alias TdPerms.RelationCache

  require Logger

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
    bcs_to_avoid_deletion = BusinessConceptCache.get_existing_business_concept_set()

    relations_from_db = Resources.list_relations()
    relations_from_db
    |> Enum.each(fn rel -> if is_business_concept_to_field(rel) &&
                            !Enum.member?(bcs_to_avoid_deletion, rel.source_id) do
        delete_relation_from_df(rel.target_id)
        RelationLoader.delete(rel)
        Resources.delete_relation(rel)
      end
    end)

    schedule_work()
    {:noreply, state}
  end

  defp delete_relation_from_df(df_id) do
    resource_key = RelationCache.get_members(df_id, "data_field")

    resource_key
    |> Enum.each(fn res -> if is_bc_nil(res) do
                            RelationCache.delete_element_from_set(res, "data_field:#{df_id}:relations")
                          end end)

  end

  defp is_bc_nil(map)do
    map
    |> RelationCache.get_resources_from_key
    |> Map.get(:business_concept_version_id) === nil
  end

  defp is_business_concept_to_field(relation) do
    relation.source_type === "business_concept" && relation.target_type === "data_field"
  end
end
