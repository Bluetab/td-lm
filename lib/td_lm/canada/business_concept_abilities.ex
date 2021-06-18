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

  def can?(%Claims{} = claims, action, %{
        resource_id: id,
        resource_type: "business_concept",
        target_type: "business_concept"
      })
      when action in [:update, :create, :delete] do
    Permissions.authorized?(claims, :manage_business_concept_links, "business_concept", id) and
      can_manage_confidential?(claims, id)
  end

  def can?(%Claims{} = claims, action, %{resource_id: id, resource_type: "business_concept"})
      when action in [:update, :create, :delete] do
    authorized?(claims, :manage_business_concept_links, id)
  end

  def can?(%Claims{}, _permission, _params) do
    false
  end

  defp authorized?(claims, permission, concept_id) do
    case get_domain_ids(concept_id) do
      [_ | _] = domain_ids ->
        Permissions.authorized?(claims, permission, "domain", domain_ids) and
          can_manage_confidential?(claims, concept_id, domain_ids)

      _ ->
        false
    end
  end

  defp authorized_any?(claims, permissions, concept_id) do
    case get_domain_ids(concept_id) do
      [_ | _] = domain_ids ->
        Permissions.authorized_any?(claims, permissions, "domain", domain_ids) and
          can_manage_confidential?(claims, concept_id, domain_ids)

      _ ->
        false
    end
  end

  defp can_manage_confidential?(claims, concept_id, domain_ids) do
    if Permissions.authorized?(
         claims,
         :manage_confidential_business_concepts,
         "domain",
         domain_ids
       ) do
      true
    else
      not ConceptCache.is_confidential?(concept_id)
    end
  end

  defp can_manage_confidential?(claims, id) do
    if Permissions.authorized?(
         claims,
         :manage_confidential_business_concepts,
         "business_concept",
         id
       ) do
      true
    else
      not ConceptCache.is_confidential?(id)
    end
  end

  defp get_domain_ids(concept_id) do
    case ConceptCache.get(concept_id) do
      {:ok, %{domain: %{id: domain_id}, shared_to_ids: shared_to_ids}} ->
        Enum.uniq([domain_id | shared_to_ids])

      _ ->
        []
    end
  end
end
