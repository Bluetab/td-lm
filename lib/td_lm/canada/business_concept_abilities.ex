defmodule TdLm.Canada.BusinessConceptAbilities do
  @moduledoc false

  alias TdLm.Accounts.User
  alias TdLm.Permissions

  # TODO: simplify business concept view permissions
  @view_business_concept [:view_approval_pending_business_concepts,
                          :view_deprecated_business_concepts,
                          :view_draft_business_concepts,
                          :view_published_business_concepts,
                          :view_rejected_business_concepts,
                          :view_versioned_business_concepts]

  def can?(%User{} = user, :add_link, %{id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :create_business_concept_link, "business_concept", id)
  end

  def can?(%User{} = user, :get_links, %{id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(user, @view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :get_link, %{id: id, resource_type: "business_concept"}) do
    Permissions.authorized_any?(user, @view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :delete_link, %{id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :delete_business_concept_link, "business_concept", id)
  end
end
