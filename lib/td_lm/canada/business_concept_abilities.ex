defmodule TdLm.Canada.TaxonomyAbilities do
  @moduledoc false

  alias TdLm.Accounts.User
  alias TdLm.Permissions

  def can?(%User{} = user, :add_link, %{id: id, resource_type: resource_type}) do
    # Authorized from permission.ex
    Permissions.authorized?(user, :update_business_concept, resource_type, id)
  end

  def can?(%User{} = user, :get_links, %{id: id, resource_type: resource_type}) do
    Permissions.authorized?(user, :view_business_concept, resource_type, id)
  end
end
