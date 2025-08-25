defmodule TdLmWeb.GraphView do
  use TdLmWeb, :view
  use TdHypermedia, :view

  alias TdLmWeb.GraphView

  def render("show.json", %{graph: graph}) do
    %{data: render_one(graph, GraphView, "graph.json")}
  end

  def render("graph.json", %{graph: graph}) do
    %{nodes: nodes_json(graph), edges: edges_json(graph)}
  end

  defp nodes_json(%{nodes: nodes}) do
    Enum.map(nodes, &node_json/1)
  end

  defp edges_json(%{edges: edges}) do
    Enum.map(edges, &edge_json/1)
  end

  defp node_json(node) do
    Map.take(node, [:id, :resource_id, :resource_type, :name, :version_id])
  end

  defp edge_json(edge) do
    tag = tag_json(edge)
    tags = if is_nil(tag), do: [], else: [tag]

    edge
    |> Map.take([:id, :source_id, :target_id])
    |> Map.put(:tags, tags)
    |> Map.put(:tag, tag)
  end

  defp tag_json(%{tag: nil}) do
    nil
  end

  defp tag_json(%{tag: tag}) do
    Map.take(tag, [:id, :value])
  end
end
