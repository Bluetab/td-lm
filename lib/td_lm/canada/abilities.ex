defmodule TdBg.Canada.Abilities do
  @moduledoc false
  alias TdLm.Accounts.User
  alias TdLm.Canada.BusinessConceptAbilities
  alias TdLm.Resources.Relation

  defimpl Canada.Can, for: User do
    # administrator is superpowerful for Domain
    def can?(%User{is_admin: true} = _user, _permission, _params) do
      true
    end

    def can?(%User{} = user, action, %Relation{} = relation) do
      resource_key = get_resource_key(relation)
      can?(user, action, resource_key)
    end

    def can?(%User{} = user, :add_link, params) do
      BusinessConceptAbilities.can?(user, :add_link, params)
    end

    def can?(%User{} = user, :get_links, params) do
      BusinessConceptAbilities.can?(user, :get_links, params)
    end

    def can?(%User{} = user, :get_link, params) do
      BusinessConceptAbilities.can?(user, :get_link, params)
    end

    def can?(%User{} = user, :delete_link, params) do
      BusinessConceptAbilities.can?(user, :delete_link, params)
    end

    def can?(%User{} = user, :search, params) do
      BusinessConceptAbilities.can?(user, :search, params)
    end

    def can?(%User{} = user, :create, params) do
      BusinessConceptAbilities.can?(user, :create, params)
    end

    def can?(%User{} = user, :show, params) do
      BusinessConceptAbilities.can?(user, :show, params)
    end

    def can?(%User{} = user, :update, params) do
      BusinessConceptAbilities.can?(user, :update, params)
    end

    def can?(%User{} = user, :delete, params) do
      BusinessConceptAbilities.can?(user, :delete, params)
    end

    def can?(%User{} = _user, _permission, _params) do
      false
    end

    defp get_resource_key(%Relation{source_type: source_type, source_id: source_id}) do
      %{resource_id: source_id, resource_type: source_type}
    end
  end
end
