defmodule TdLm.Canada.BusinessConceptAbilities do
  @moduledoc false

  alias TdCache.ConceptCache
  alias TdLm.Auth.Claims
  alias TdLm.Permissions

  @view_business_concept [
    :view_approval_pending_business_concepts,
    :view_deprecated_business_concepts,
    :view_draft_business_concepts,
    :view_published_business_concepts,
    :view_rejected_business_concepts,
    :view_versioned_business_concepts
  ]

  def can?(%Claims{} = claims, :search, %{resource_id: id, resource_type: "business_concept"}) do
    authorized_any?(claims, @view_business_concept, id)
  end

  def can?(%Claims{} = claims, :show, %{resource_id: id, resource_type: "business_concept"}) do
    authorized_any?(claims, @view_business_concept, id)
  end

  def can?(%Claims{} = claims, :update, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(claims, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%Claims{} = claims, :create, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(claims, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%Claims{} = claims, :delete, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(claims, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%Claims{}, _permission, _params) do
    false
  end

  defp authorized_any?(claims, permissions, concept_id) do
    case ConceptCache.get(concept_id) do
      {:ok, %{domain_id: domain_id, shared_to_ids: shared_to_ids}} ->
        domain_ids =
          shared_to_ids
          |> Enum.concat([domain_id])
          |> Enum.uniq()

        Permissions.authorized_any?(claims, permissions, "domain", domain_ids) and
          can_manage_confidential?(claims, concept_id, domain_ids)

      _ ->
        false
    end
  end

  defp can_manage_confidential?(claims, concept_id, domain_ids) do
    case Permissions.authorized?(
           claims,
           :manage_confidential_business_concepts,
           "domain",
           domain_ids
         ) do
      false ->
        {:ok, confidentials} = ConceptCache.confidential_ids()
        not Enum.member?(confidentials, concept_id)

      _ ->
        true
    end
  end
end
