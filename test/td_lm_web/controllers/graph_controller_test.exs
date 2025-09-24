defmodule TdLmWeb.GraphControllerTest do
  use TdLmWeb.ConnCase

  alias TdCache.ConceptCache

  setup %{conn: conn} do
    start_supervised!(TdLm.Cache.LinkLoader)
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "graph" do
    setup context do
      tag =
        if context[:without_tag] do
          nil
        else
          insert(:tag)
        end

      relations =
        Enum.map(1..10, fn id ->
          insert(:relation,
            source_type: "business_concept",
            target_type: "business_concept",
            source_id: id,
            target_id: id + 1,
            status: "approved",
            tag: tag
          )
        end)

      [relations: relations, tag: tag]
    end

    @tag authentication: [role: "admin"]
    test "get all relations with tag", %{conn: conn, tag: tag} do
      id = "11"
      type = "business_concept"

      edge_tag = %{"id" => tag.id, "value" => tag.value}

      assert %{"data" => %{"nodes" => [_ | _] = nds, "edges" => [_ | _] = eds}} =
               conn
               |> get(Routes.graph_path(conn, :graph, id), %{"type" => type})
               |> json_response(:ok)

      assert Enum.all?(1..11, &Enum.find(nds, fn n -> Map.get(n, "id") == "#{type}:#{&1}" end))

      assert Enum.all?(
               1..10,
               &Enum.find(eds, fn n ->
                 Map.get(n, "source_id") == "#{type}:#{&1}" and
                   Map.get(n, "target_id") == "#{type}:#{&1 + 1}" and
                   Map.get(n, "tag") == edge_tag and Map.get(n, "tags") == [edge_tag]
               end)
             )
    end

    @tag authentication: [role: "admin"], without_tag: true
    test "get all relations without tag", %{conn: conn} do
      id = "11"
      type = "business_concept"

      assert %{"data" => %{"nodes" => [_ | _] = nds, "edges" => [_ | _] = eds}} =
               conn
               |> get(Routes.graph_path(conn, :graph, id), %{"type" => type})
               |> json_response(:ok)

      assert Enum.count(nds) == 11

      assert Enum.all?(1..11, &Enum.find(nds, fn n -> Map.get(n, "id") == "#{type}:#{&1}" end))

      assert Enum.all?(
               1..10,
               &Enum.find(eds, fn n ->
                 Map.get(n, "source_id") == "#{type}:#{&1}" and
                   Map.get(n, "target_id") == "#{type}:#{&1 + 1}" and
                   Enum.empty?(Map.get(n, "tags")) and is_nil(Map.get(n, "tag"))
               end)
             )
    end

    @tag authentication: [role: "admin"]
    test "get all relations only with status approved or nil", %{conn: conn, tag: tag} do
      id = "11"
      type = "business_concept"

      insert(:relation,
        source_type: "business_concept",
        target_type: "business_concept",
        source_id: id,
        target_id: 13,
        tag: tag,
        status: "pending"
      )

      insert(:relation,
        source_type: "business_concept",
        target_type: "business_concept",
        source_id: id,
        target_id: 14,
        tag: tag,
        status: "rejected"
      )

      insert(:relation,
        source_type: "business_concept",
        target_type: "business_concept",
        source_id: id,
        target_id: 16,
        tag: tag,
        status: nil
      )

      assert %{"data" => %{"nodes" => [_ | _] = nds, "edges" => [_ | _]}} =
               conn
               |> get(Routes.graph_path(conn, :graph, id), %{"type" => type})
               |> json_response(:ok)

      assert Enum.count(nds) == 12
    end

    @tag authentication: [role: "admin"]
    test "get all relations with data in browser language", %{
      conn: conn,
      relations: [%{source_id: source_id, target_id: target_id} | _]
    } do
      concept_source =
        build(:business_concept, id: source_id, name: "source_en", content: %{"foo" => "foo_en"})

      concept_target =
        build(:business_concept, id: target_id, name: "target_en", content: %{"bar" => "bar_en"})

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
