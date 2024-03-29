defmodule TdBg.Canada.Abilities do
  @moduledoc false
  alias TdLm.Auth.Claims
  alias TdLm.Canada.BusinessConceptAbilities
  alias TdLm.Canada.ImplementationAbilities
  alias TdLm.Canada.IngestAbilities
  alias TdLm.Resources.Relation

  defimpl Canada.Can, for: Claims do
    # administrator is superpowerful for Domain
    def can?(%Claims{role: "admin"}, _permission, _params) do
      true
    end

    def can?(%Claims{} = claims, action, %Relation{} = relation) do
      resource_key = get_resource_key(relation)
      can?(claims, action, resource_key)
    end

    def can?(%Claims{} = claims, :search, %{resource_type: "business_concept"} = params) do
      BusinessConceptAbilities.can?(claims, :search, params)
    end

    def can?(%Claims{} = claims, :create, %{resource_type: "business_concept"} = params) do
      BusinessConceptAbilities.can?(claims, :create, params)
    end

    def can?(%Claims{} = claims, :show, %{resource_type: "business_concept"} = params) do
      BusinessConceptAbilities.can?(claims, :show, params)
    end

    def can?(%Claims{} = claims, :update, %{resource_type: "business_concept"} = params) do
      BusinessConceptAbilities.can?(claims, :update, params)
    end

    def can?(%Claims{} = claims, :delete, %{resource_type: "business_concept"} = params) do
      BusinessConceptAbilities.can?(claims, :delete, params)
    end

    def can?(%Claims{} = claims, :search, %{resource_type: "ingest"} = params) do
      IngestAbilities.can?(claims, :search, params)
    end

    def can?(%Claims{} = claims, :create, %{resource_type: "ingest"} = params) do
      IngestAbilities.can?(claims, :create, params)
    end

    def can?(%Claims{} = claims, :show, %{resource_type: "ingest"} = params) do
      IngestAbilities.can?(claims, :show, params)
    end

    def can?(%Claims{} = claims, :update, %{resource_type: "ingest"} = params) do
      IngestAbilities.can?(claims, :update, params)
    end

    def can?(%Claims{} = claims, :delete, %{resource_type: "ingest"} = params) do
      IngestAbilities.can?(claims, :delete, params)
    end

    def can?(%Claims{} = claims, :create, %{resource_type: "implementation_ref"} = params) do
      ImplementationAbilities.can?(claims, :create, params)
    end

    def can?(%Claims{} = claims, :delete, %{resource_type: "implementation_ref"} = params) do
      ImplementationAbilities.can?(claims, :delete, params)
    end

    def can?(%Claims{}, _permission, _params) do
      false
    end

    defp get_resource_key(%Relation{
           source_type: source_type,
           source_id: source_id,
           target_type: target_type
         }) do
      %{resource_id: source_id, resource_type: source_type, target_type: target_type}
    end
  end
end
