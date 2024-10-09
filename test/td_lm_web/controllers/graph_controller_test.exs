defmodule TdLmWeb.GraphControllerTest do
  use TdLmWeb.ConnCase

  alias TdCache.ConceptCache

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

    @tag authentication: [role: "admin"]
    test "get all relations with data in browser language", %{
      conn: conn,
      relations: [%{source_id: source_id, target_id: target_id} | _]
    } do
      concept_source =
        build(:concept, id: source_id, name: "source_en", content: %{"foo" => "foo_en"})

      concept_target =
        build(:concept, id: target_id, name: "target_en", content: %{"bar" => "bar_en"})

      concept_source_es_name = "source_es"
      concept_source_es_value = "foo_es"
      concept_target_es_name = "target_es"
      concept_target_es_value = "bar_es"

      concept_source_18n = %{
        "es" => %{
          "name" => concept_source_es_name,
          "content" => %{"foo" => concept_source_es_value}
        }
      }

      concept_target_18n = %{
        "es" => %{
          "name" => concept_target_es_name,
          "content" => %{"bar" => concept_target_es_value}
        }
      }

      {:ok, _} = ConceptCache.put(Map.put(concept_source, :i18n, concept_source_18n))
      {:ok, _} = ConceptCache.put(Map.put(concept_target, :i18n, concept_target_18n))

      id = "11"
      type = "business_concept"

      assert %{
               "data" => %{
                 "nodes" => [
                   %{"name" => ^concept_source_es_name},
                   %{"name" => ^concept_target_es_name} | _
                 ]
               }
             } =
               conn
               |> put_req_header("accept-language", "es")
               |> get(Routes.graph_path(conn, :graph, id), %{"type" => type})
               |> json_response(:ok)
    end
  end
end
