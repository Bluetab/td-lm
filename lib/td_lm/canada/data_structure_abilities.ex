defmodule TdLm.Canada.DataStructureAbilities do
  @moduledoc false

  alias TdLm.Auth.Claims
  alias TdLm.Permissions

  def can?(%Claims{} = claims, :create, %{
        target_type: "data_structure",
        structure: %{domain_ids: domain_ids}
      }) do
    Permissions.authorized?(claims, :view_data_structure, domain_ids) and
      Permissions.authorized?(claims, :link_data_structure, domain_ids)
  end

  def can?(%Claims{}, _permission, _params) do
    false
  end
end
