defmodule TdLmWeb.GraphControllerTest do
  use TdLmWeb.ConnCase

  setup_all do
    start_supervised(TdLm.Cache.LinkLoader)
    :ok
  end

  setup %{conn: conn} do
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "graph" do
    setup do
      tags = Enum.map(1..5, fn _ -> insert(:tag) end)

      relations =
        Enum.map(1..10, fn id ->
          insert(:relation,
            source_type: "business_concept",
            target_type: "business_concept",
            source_id: id,
            target_id: id + 1,
            tags: tags
          )
        end)

      [relations: relations, tags: tags]
    end

    @tag authentication: [role: "admin"]
    test "get all relations", %{conn: conn} do
      id = "11"
      type = "business_concept"

      assert %{"data" => %{"nodes" => [_ | _] = nds, "edges" => [_ | _] = eds}} =
               conn
               |> get(Routes.graph_path(conn, :graph, id), %{"type" => type})
               |> json_response(:ok)

      assert Enum.all?(1..11, &Enum.find(nds, fn n -> Map.get(n, "id") == "#{type}:#{&1}" end))

      assert Enum.all?(
               1..10,
               &Enum.find(eds, fn n ->
                 Map.get(n, "source_id") == "#{type}:#{&1}" and
                   Map.get(n, "target_id") == "#{type}:#{&1 + 1}"
               end)
             )
    end
  end
end
