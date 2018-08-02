defmodule TdLm.Canada.BusinessConceptAbilities do
  @moduledoc false

  alias TdLm.Accounts.User
  alias TdLm.Permissions

  def can?(%User{} = user, :add_link, %{id: id, resource_type: "business_concept"}) do
    # Authorized from permission.ex
    Permissions.authorized?(user, :update_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :get_links, %{id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :get_link, %{id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :view_business_concept, "business_concept", id)
  end

  def can?(%User{} = user, :delete_link, %{id: id, resource_type: "business_concept"}) do
    Permissions.authorized?(user, :update_business_concept, "business_concept", id)
  end
end
