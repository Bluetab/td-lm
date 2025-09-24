defmodule TdLm.Graph.Data do
  @moduledoc false
  alias Graph.Traversal

  alias TdLm.Resources

  def graph do
    %{"status" => "approved"}
    |> Resources.list_relations()
    |> Enum.reduce(Graph.new([]), &reduce_relation/2)
  end

  def id(type, id), do: "#{type}:#{id}"

  defp reduce_relation(
         %{
           id: id,
           source_id: source_id,
           source_type: source_type,
           target_id: target_id,
           target_type: target_type,
           tag: tag
         },
         %Graph{} = g
       ) do
    g
    |> Graph.add_vertex(id(source_type, source_id),
      resource_type: source_type,
      resource_id: source_id
    )
    |> Graph.add_vertex(id(target_type, target_id),
      resource_type: target_type,
      resource_id: target_id
    )
    |> Graph.add_edge(id, id(source_type, source_id), id(target_type, target_id), tag: tag)
  end

  def reachable(%Graph{} = g, ids) when is_list(ids), do: Traversal.reachable(ids, g)
  def reachable(%Graph{} = g, id), do: reachable(g, [id])

  def reaching(%Graph{} = g, ids) when is_list(ids), do: Traversal.reaching(ids, g)
  def reaching(%Graph{} = g, id), do: reaching(g, [id])

  def all(%Graph{} = g, ids) when is_list(ids),
    do: Enum.concat(reaching(g, ids), reachable(g, ids))

  def all(%Graph{} = g, id), do: all(g, [id])

  def subgraph(g, ids), do: Graph.subgraph(g, ids)
end
