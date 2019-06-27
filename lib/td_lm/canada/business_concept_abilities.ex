defmodule TdLm.Canada.BusinessConceptAbilities do
  @moduledoc false

  alias TdLm.Accounts.User
  alias TdLm.Permissions

  @view_business_concept [
    :view_approval_pending_business_concepts,
    :view_deprecated_business_concepts,
    :view_draft_business_concepts,
    :view_published_business_concepts,
    :view_rejected_business_concepts,
    :view_versioned_business_concepts
  ]

  def can?(%User{} = user, :add_link, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%User{} = user, :get_links, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(user, @view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :get_link, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(user, @view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :delete_link, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%User{} = user, :search, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(user, @view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :show, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(user, @view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :update, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%User{} = user, :create, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%User{} = user, :delete, %{resource_id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :manage_business_concept_links, "business_concept", id)
  end

  def can?(%User{} = _user, _permission, _params) do
    false
  end
end
