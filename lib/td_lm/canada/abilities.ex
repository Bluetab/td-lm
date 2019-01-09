defmodule TdBg.Canada.Abilities do
  @moduledoc false
  alias TdLm.Accounts.User
  alias TdLm.Canada.BusinessConceptAbilities

  defimpl Canada.Can, for: User do
    # administrator is superpowerful for Domain
    def can?(%User{is_admin: true} = _user, _permission, _params) do
      true
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

    def can?(%User{} = user, :create, %{"relation_type" => "business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :create, params)
    end

    def can?(%User{} = user, :create, %{"relation_type" => "master_business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :create, params)
    end

    def can?(%User{} = user, :show, %{"relation_type" => "business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :show, params)
    end

    def can?(%User{} = user, :show, %{"relation_type" => "master_business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :show, params)
    end

    def can?(%User{} = user, :update, %{"relation_type" => "business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :update, params)
    end

    def can?(%User{} = user, :update, %{"relation_type" => "master_business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :update, params)
    end

    def can?(%User{} = user, :delete, %{"relation_type" => "business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :delete, params)
    end

    def can?(%User{} = user, :delete, %{"relation_type" => "master_business_concept_to_field"} = params) do
      BusinessConceptAbilities.can?(user, :delete, params)
    end

    def can?(%User{} = _user, _permission, _params) do
      false
    end
  end
end
