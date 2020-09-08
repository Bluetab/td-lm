defmodule TdLmWeb.GraphController do
  use TdHypermedia, :controller
  use TdLmWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCache.ConceptCache
  alias TdCache.IngestCache
  alias TdCache.StructureCache
  alias TdLm.Resources

  require Logger

  action_fallback(TdLmWeb.FallbackController)

  def graph(conn, %{"resource_id" => id, "type" => type}) do
    user = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(user, show(%{resource_type: type, resource_id: id}))},
         %{nodes: nodes, edges: edges} <-
           Resources.graph(user, id, type, types: ["business_concept"]) do
      nodes = enrich_nodes(nodes)
      render(conn, "show.json", graph: %{nodes: nodes, edges: edges})
    end
  end

  defp enrich_nodes(nodes) do
    Enum.map(nodes, &enrich_node/1)
  end

  defp enrich_node(%{resource_id: id, resource_type: "business_concept"} = node) do
    {:ok, c} = ConceptCache.get(id)

    case c do
      nil ->
        node

      _ ->
        node
        |> Map.put(:name, Map.get(c, :name))
        |> Map.put(:version_id, Map.get(c, :business_concept_version_id))
    end
  end

  defp enrich_node(%{resource_id: id, resource_type: "ingest"} = node) do
    {:ok, i} = IngestCache.get(id)

    node
    |> Map.put(:name, Map.get(i, :name))
    |> Map.put(:version_id, Map.get(i, :ingest_version_id))
  end

  defp enrich_node(%{resource_id: id, resource_type: "data_structure"} = node) do
    {:ok, d} = StructureCache.get(id)
    Map.put(node, :name, Map.get(d, :name))
  end

  defp enrich_node(node), do: node
end
