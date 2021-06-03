defmodule TdLmWeb.RelationView do
  use TdLmWeb, :view
  use TdHypermedia, :view

  alias TdLmWeb.RelationView

  def render("index.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, RelationView, "relation.json")
  end

  def render("index.json", %{relations: relations}) do
    %{data: render_many(relations, RelationView, "relation.json")}
  end

  def render("show.json", %{relation: relation}) do
    %{data: render_one(relation, RelationView, "relation.json")}
  end

  def render("relation.json", %{relation: relation}) do
    relation_json(relation)
  end

  defp relation_json(relation) do
    tags = parse_relation_tags(relation)

    relation
    |> Map.take([:id, :context, :source_id, :source_type, :target_id, :target_type])
    |> Map.put(:tags, tags)
  end

  defp parse_relation_tags(relation) do
    case Ecto.assoc_loaded?(relation.tags) do
      true ->
        relation
        |> Map.get(:tags, [])
        |> Enum.map(&Map.take(&1, [:id, :value]))

      false ->
        []
    end
  end
end
