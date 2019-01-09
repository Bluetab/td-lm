defmodule TdLmWeb.RelationView do
  use TdLmWeb, :view
  use TdHypermedia, :view
  
  alias TdLmWeb.RelationView

  def render("index.json", %{relations: relations, hypermedia: hypermedia}) do
    %{data: render_many_hypermedia(relations, hypermedia, RelationView, "relation.json")}
  end

  def render("index.json", %{relations: relations}) do
    %{data: render_many(relations, RelationView, "relation.json")}
  end

  def render("show.json", %{relation: relation}) do
    %{data: render_one(relation, RelationView, "relation.json")}
  end

  def render("relation.json", %{relation: relation}) do
    %{id: relation.id,
      context: relation.context,
      relation_type: relation.relation_type,
      source_id: relation.source_id,
      source_type: relation.source_type,
      target_id: relation.target_id,
      target_type: relation.target_type
    }
  end
end
