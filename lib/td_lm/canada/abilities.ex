defmodule TdBg.Canada.Abilities do
  @moduledoc false
  alias TdLm.Accounts.User
  alias TdLm.Canada.TaxonomyAbilities

  defimpl Canada.Can, for: User do
    # administrator is superpowerful for Domain
    def can?(%User{is_admin: true} = _user, _permission, _domain), do: true
    def can?(%User{} = user, :add_field, domain_id) do
      TaxonomyAbilities.can?(user, :add_field, domain_id)
    end
  end
end
