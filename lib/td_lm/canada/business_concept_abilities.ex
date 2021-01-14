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

  def can?(%Claims{} = claims, :add_link, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(claims, :manage_business_concept_links, "business_concept", id) and
      can_manage_confidential?(claims, id)
  end

  def can?(%Claims{} = claims, :get_links, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(claims, @view_business_concept, "business_concept", id) and
      can_manage_confidential?(claims, id)
  end

  def can?(%Claims{} = claims, :get_link, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(claims, @view_business_concept, "business_concept", id) and
      can_manage_confidential?(claims, id)
  end

  def can?(%Claims{} = claims, :delete_link, %{
        resource_id: id,
        resource_type: "business_concept"
      }) do
    Permissions.authorized?(claims, :manage_business_concept_links, "business_concept", id) and
      can_manage_confidential?(claims, id)
  end

  def can?(%Claims{} = claims, :search, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(claims, @view_business_concept, "business_concept", id) and
      can_manage_confidential?(claims, id)
  end

  def can?(%Claims{} = claims, :show, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(claims, @view_business_concept, "business_concept", id) and
      can_manage_confidential?(claims, id)
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

  defp can_manage_confidential?(claims, id) do
    case Permissions.authorized?(
           claims,
           :manage_confidential_business_concepts,
           "business_concept",
           id
         ) do
      false ->
        {:ok, confidentials} = ConceptCache.confidential_ids()
        not Enum.member?(confidentials, id)

      _ ->
        true
    end
  end
end
