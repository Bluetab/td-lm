defmodule TdLm.Graph.DataTest do
  use TdLm.DataCase

  alias Graph
  alias TdLm.Graph.Data

  setup do
    tags = Enum.map(1..5, fn _ -> insert(:tag) end)

    relations =
      Enum.map(1..10, fn id ->
        insert(:relation,
          source_type: "business_concept",
          target_type: "business_concept",
          source_id: "#{id}",
          target_id: "#{id + 1}",
          tags: tags
        )
      end)

    [relations: relations, tags: tags]
  end

  describe "Graph.Data" do
    test "graph/0 creates a graph", %{relations: relations} do
      ids = Enum.map(1..11, fn i -> "#{i}" end)
      assert %Graph{} = graph = Data.graph()
      Enum.all?(ids, fn id -> id in Graph.vertices(graph) end)

      Enum.all?(relations, fn %{
                                source_id: source_id,
                                target_id: target_id,
                                source_type: source_type,
                                target_type: target_type
                              } ->
        Graph.has_edge?(graph, "#{source_type}:#{source_id}", "#{target_type}:#{target_id}")
      end)
    end

    test "reachable/2 gets all reachable nodes" do
      ids = Enum.map(1..11, fn i -> "business_concept:#{i}" end)
      assert %Graph{} = graph = Data.graph()
      assert Enum.all?(ids, fn id -> id in Data.reachable(graph, "business_concept:1") end)
      assert Data.reachable(graph, "business_concept:11") == ["business_concept:11"]
    end

    test "reaching/2 gets all reaching nodes" do
      ids = Enum.map(1..11, fn i -> "business_concept:#{i}" end)
      assert %Graph{} = graph = Data.graph()
      assert Enum.all?(ids, fn id -> id in Data.reaching(graph, "business_concept:11") end)
      assert Data.reaching(graph, "business_concept:1") == ["business_concept:1"]
    end

    test "all/2 gets all connected nodes" do
      ids = Enum.map(1..11, fn i -> "business_concept:#{i}" end)
      assert %Graph{} = graph = Data.graph()
      assert Enum.all?(ids, fn id -> id in Data.all(graph, "business_concept:5") end)
      assert Enum.all?(ids, fn id -> id in Data.all(graph, "business_concept:11") end)
    end
  end
end
