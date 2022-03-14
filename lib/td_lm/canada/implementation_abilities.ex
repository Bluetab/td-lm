defmodule TdLm.Canada.ImplementationAbilities do
  @moduledoc false
  alias TdLm.Auth.Claims
  alias TdLm.Permissions

  def can?(%Claims{} = claims, action, %{resource_id: _id, resource_type: "implementation"})
      when action in [:create, :delete] do
    Permissions.has_any_permission?(
      claims,
      [:link_implementation_business_concept]
    )
  end

  def can?(%Claims{}, _permission, _params) do
    false
  end
end
