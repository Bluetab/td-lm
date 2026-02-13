defmodule TdLm.Search.Query do
  @moduledoc """
  Builds Elasticsearch queries for relations
  """

  alias TdCluster.TdBg
  alias TdCluster.TdDd
  alias TdCore.Search.Permissions
  alias TdCore.Search.Query

  @structure_permissions [
    "view_data_structure",
    "manage_confidential_structures",
    "link_data_structure"
  ]
  @quality_control_permissions [
    "view_quality_controls",
    "link_quality_control_to_concept",
    "link_quality_control_to_structure"
  ]
  @types ["business_concept", "data_structure", "quality_control"]

  def build_permissions(claims, opts \\ []) do
    [clause_for_resource("source", claims, opts), clause_for_resource("target", claims, opts)]
  end

  defp clause_for_resource(resource, claims, opts) do
    should = Enum.map(@types, &permission_filter_for_type(&1, resource, claims, opts))
    %{bool: %{should: should}}
  end

  defp permission_filter_for_type("business_concept", resource, claims, opts) do
    prefix = prefix(resource)
    type_field = type_field(resource)

    {:ok, permissions} = TdBg.Permissions.default_permissions()

    permissions
    |> Permissions.get_search_permissions(claims)
    |> TdBg.Search.build_filters(field_prefix: prefix, linkable: opts[:linkable])
    |> then(fn {:ok, response} -> bool_filter(response, "business_concept", type_field) end)
  end

  defp permission_filter_for_type("data_structure", resource, claims, opts) do
    prefix = prefix(resource)
    type_field = type_field(resource)

    permissions =
      if opts[:linkable],
        do: @structure_permissions -- ["view_data_structure"],
        else: @structure_permissions -- ["link_data_structure"]

    permissions
    |> Permissions.get_search_permissions(claims)
    |> TdDd.Search.build_filters(field_prefix: prefix)
    |> then(fn {:ok, response} -> bool_filter(response, "data_structure", type_field) end)
  end

  defp permission_filter_for_type("quality_control", resource, claims, opts) do
    prefix = prefix(resource)
    type_field = type_field(resource)

    permissions =
      if opts[:linkable],
        do: @quality_control_permissions -- ["view_quality_controls"],
        else:
          @quality_control_permissions --
            ["link_quality_control_to_concept", "link_quality_control_to_structure"]

    permissions
    |> Permissions.filter_for_permissions(claims, field_prefix: prefix)
    |> bool_filter("quality_control", type_field)
  end

  defp prefix("source"), do: "source_data."
  defp prefix("target"), do: "target_data."

  defp type_field("source"), do: "source_type"
  defp type_field("target"), do: "target_type"

  defp bool_filter(%{} = bool, type, type_field) do
    %{bool: %{filter: [Query.term_or_terms(type_field, type), bool]}}
  end

  defp bool_filter([_ | _] = clauses, type, type_field) do
    %{bool: %{filter: [Query.term_or_terms(type_field, type) | clauses]}}
  end
end
