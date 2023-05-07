defmodule TdLm.RelationRemover do
  @moduledoc """
  Provides functionality for removing relations associated with deleted
  business concepts.
  """
  require Logger

  alias TdCache.ConceptCache
  alias TdCache.ImplementationCache
  alias TdLm.Auth.Claims
  alias TdLm.Cache.LinkLoader
  alias TdLm.Resources

  @system_claims %Claims{user_id: 0, user_name: "system"}

  ## Client API
  def delete_stale_relations do
    remove_stale_concept_relations()
    remove_stale_implementation_relations()
  end

  def remove_stale_concept_relations do
    case ConceptCache.active_ids() do
      {:ok, []} ->
        :ok

      {:ok, active_ids} ->
        hard_deletion("business_concept", active_ids)

      _ ->
        :ok
    end
  end

  def remove_stale_implementation_relations do
    case ImplementationCache.list() do
      [] ->
        :ok

      active_implementations ->
        active_implementations
        |> Enum.map(fn active_implementation ->
          active_implementation
          |> String.replace_prefix("implementation:", "")
          |> String.to_integer()
        end)
        # LinkLoader.delete publishes a delete_link event that is
        # processed by LinkRemover, which deletes from DB using
        # Resources.delete_relation.
        |> then(&link_loader_deletion("implementation_ref", &1))
    end
  end

  ## Private functions

  defp hard_deletion(_, []), do: :ok

  defp hard_deletion(resource_type, active_ids) do
    stale_relations = Resources.list_stale_relations(resource_type, active_ids)

    stale_relations
    |> Enum.map(& &1.id)
    |> LinkLoader.delete()

    stale_relations
    |> Enum.each(&Resources.delete_relation(&1, @system_claims))
  end

  defp link_loader_deletion(_, []), do: :ok

  defp link_loader_deletion(resource_type, active_ids) do
    stale_relations = Resources.list_stale_relations(resource_type, active_ids)

    stale_relations
    |> Enum.map(& &1.id)
    |> LinkLoader.delete()
  end
end
