defmodule TdLmWeb.RelationView do
  use TdLmWeb, :view
  use TdHypermedia, :view

  alias TdLmWeb.RelationView

  @tag_attrs [:id, :value]

  def render("index.json", %{relations: relations, hypermedia: hypermedia}) do
    render_many_hypermedia(relations, hypermedia, RelationView, "relation.json")
  end

  def render("index.json", %{relations: relations}) do
    %{data: render_many(relations, RelationView, "relation.json")}
  end

  def render("show.json", %{relation: relation}) do
    %{data: render_one(relation, RelationView, "relation.json")}
  end

  def render("relation.json", %{relation: relation}) do
    relation
    |> relation_json()
  end

  defp relation_json(relation) do
    %{
      id: relation.id,
      context: relation.context,
      source_id: relation.source_id,
      source_type: relation.source_type,
      target_id: relation.target_id,
      target_type: relation.target_type,
      tags: parse_relation_tags(relation)
    }
  end

  defp parse_relation_tags(relation) do
    case Ecto.assoc_loaded?(relation.tags) do
      true ->
        relation
          |> Map.get(:tags, [])
          |> Enum.map(&Enum.take(&1, @tag_attrs))
      false ->
        []
    end
  end
end
