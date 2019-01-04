defmodule TdLm.Repo.Migrations.LoadDataFromResourceLinkIntoRelations do
  use Ecto.Migration
  
  import Ecto.Query
  alias TdLm.Repo
  alias TdLm.Resources.Relation

  def change do
    resource_link_entities = fetch_entities_in_resource_links()
    Repo.insert_all(Relation, resource_link_entities)
  end

  defp fetch_entities_in_resource_links do
    resource_links = 
      from(
        r_l in "resource_links", 
        select: 
          %{
            source_id: r_l.resource_id, 
            source_type: r_l.resource_type,
            target: r_l.field
          }
        )
      |> Repo.all()
    
    parse_resource_link_format(resource_links)
  end

  defp parse_resource_link_format(resource_links) do
    inserted_at = DateTime.utc_now()
    updated_at = DateTime.utc_now()

    resource_links
    |> Enum.map(&resource_link_format(&1, inserted_at, updated_at))
  end

  defp resource_link_format(%{source_id: source_id, source_type: source_type, target: target}, inserted_at, updated_at) do
    Map.new()
    |> Map.put(:source_id, source_id)
    |> Map.put(:source_type, source_type)
    |> Map.put(:target_id, target |> Map.get("field_id") |> Integer.to_string())
    |> Map.put(:inserted_at, inserted_at)
    |> Map.put(:updated_at, updated_at)
    |> Map.put(:target_type, "field")
    |> Map.put(:relation_type, "business_concept_to_field")
    |> Map.put(:context, build_target_context(target))
  end

  defp build_target_context(target) do
    target_params = 
      target
      |> Map.drop(["ou", "field_id"])

    Map.new() |> Map.put("target", target_params)
  end
end
