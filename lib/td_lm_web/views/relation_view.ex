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
    relation
    |> Map.take([
      :context,
      :id,
      :inserted_at,
      :source_id,
      :source_type,
      :target_id,
      :target_type,
      :status,
      :origin,
      :updated_at,
      :tag_id,
      :tag,
      :tags
    ])
    |> add_tag_type()
  end

  defp add_tag_type(%{tag: %{value: %{"type" => type}}} = relation) do
    Map.put(relation, :tag_type, type)
  end

  defp add_tag_type(relation), do: Map.put(relation, :tag_type, nil)
end
