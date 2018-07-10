defmodule TdLm.Canada.TaxonomyAbilities do
  @moduledoc false

  alias TdLm.Accounts.User
  alias TdLm.Permissions

  def can?(%User{} = user, :add_field, domain_id) do
    # Authorized from permission.ex
    Permissions.authorized?(user, :update_business_concept, domain_id)
  end
end
