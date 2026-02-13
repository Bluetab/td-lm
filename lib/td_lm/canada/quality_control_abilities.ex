defmodule TdLm.Canada.QualityControlAbilities do
  @moduledoc false

  alias TdCluster.Cluster.TdQx
  alias TdLm.Auth.Claims

  def can?(%Claims{} = claims, :link_quality_control_to_concept, quality_control_id) do
    authorized?(claims, :link_quality_control_to_concept, quality_control_id)
  end

  def can?(%Claims{} = claims, :link_quality_control_to_structure, quality_control_id) do
    authorized?(claims, :link_quality_control_to_structure, quality_control_id)
  end

  defp authorized?(claims, permission, resource_id) do
    case TdQx.get_quality_control(resource_id) do
      {:ok, %{domain_ids: domain_ids}} ->
        TdLm.Permissions.authorized?(claims, permission, domain_ids)

      _ ->
        false
    end
  end
end
