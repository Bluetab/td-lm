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
    tags = relation_tags(relation)

    relation
    |> Map.take([
      :context,
      :id,
      :inserted_at,
      :source_id,
      :source_type,
      :target_id,
      :target_type,
      :updated_at
    ])
    |> Map.put(:tags, tags)
  end

  defp relation_tags(%{tags: tags}) do
    if Ecto.assoc_loaded?(tags) do
      Enum.map(tags, &Map.take(&1, [:id, :value]))
    else
      []
    end
  end
end
