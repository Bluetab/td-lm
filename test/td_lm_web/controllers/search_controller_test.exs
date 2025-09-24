defmodule TdLmWeb.SearchControllerTest do
  use TdLmWeb.ConnCase

  import Mox

  @permissions ["manage_business_concept_links", "link_data_structure"]

  setup do
    %{id: concept_id} = concept = CacheHelpers.put_concept()
    %{id: structure_id} = structure = CacheHelpers.put_structure()

    relation =
      generate_relation(%{
        source_type: "business_concept",
        source_id: concept_id,
        target_type: "data_structure",
        target_id: structure_id,
        origin: "suggested",
        status: "pending"
      })

    [relation: relation, concept: concept, structure: structure]
  end

  setup {Mox, :verify_on_exit!}

  describe "POST /api/relations/index_search" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} can search relations", %{conn: conn, relation: relation} do
        %{
          id: relation_id,
          source_id: relation_source_id,
          source_type: relation_source_type,
          source_data: %{name: relation_source_name, domain_ids: relation_source_domain_ids},
          target_id: relation_target_id,
          target_type: relation_target_type,
          target_data: %{name: relation_target_name, domain_ids: relation_target_domain_ids},
          origin: relation_origin,
          status: relation_status
        } = relation

        ElasticsearchMock
        |> expect(:request, fn
          _,
          :post,
          "/relations/_search",
          %{
            size: 20,
            sort: ["_score", "updated_at"],
            from: 0,
            query: query
          },
          _ ->
            assert %{bool: %{must: %{match_all: %{}}}} = query
            SearchHelpers.hits_response([relation])
        end)

        assert %{"data" => data} =
                 conn
                 |> post(Routes.search_path(conn, :create, %{}))
                 |> json_response(:ok)

        domain_ids = relation_source_domain_ids ++ relation_target_domain_ids

        assert [
                 %{
                   "id" => ^relation_id,
                   "domain_ids" => ^domain_ids,
                   "source_domain_ids" => ^relation_source_domain_ids,
                   "source_id" => ^relation_source_id,
                   "source_name" => ^relation_source_name,
                   "source_type" => ^relation_source_type,
                   "target_domain_ids" => ^relation_target_domain_ids,
                   "target_id" => ^relation_target_id,
                   "target_name" => ^relation_target_name,
                   "target_type" => ^relation_target_type,
                   "origin" => ^relation_origin,
                   "status" => ^relation_status
                 }
               ] = data
      end
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "user with permissions can search relations", %{
      conn: conn,
      domain: %{id: domain_id} = domain_1,
      concept: concept,
      structure: structure
    } do
      domain_2 = CacheHelpers.put_domain()

      relation =
        generate_relation(
          %{
            source_type: "business_concept",
            source_id: concept.id,
            target_type: "data_structure",
            target_id: structure.id,
            origin: "suggested",
            status: "pending"
          },
          [domain_1, domain_2]
        )

      ElasticsearchMock
      |> expect(:request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert %{bool: %{must: %{term: %{"domain_ids" => ^domain_id}}}} = query

          SearchHelpers.hits_response([relation])
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.search_path(conn, :create, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permissions return empty", %{
      conn: conn
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _,
        :post,
        "/relations/_search",
        %{
          size: 20,
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert %{bool: %{must: %{match_none: %{}}}} = query
          SearchHelpers.hits_response([])
      end)

      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :create, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "search relations with scroll", %{
      conn: conn,
      concept: concept,
      structure: structure,
      domain: domain_1
    } do
      domain_2 = CacheHelpers.put_domain()

      relation =
        generate_relation(
          %{
            source_type: "business_concept",
            source_id: concept.id,
            target_type: "data_structure",
            target_id: structure.id,
            origin: "suggested",
            status: "pending"
          },
          [domain_1, domain_2]
        )

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/relations/_search", _, [params: %{"scroll" => "1m"}] ->
        SearchHelpers.scroll_response([relation], 7)
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", %{"scroll_id" => "some_scroll_id"}, _ ->
        SearchHelpers.scroll_response([], 7)
      end)

      assert %{"data" => _, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.search_path(conn, :create, %{"scroll" => "1m"}))
               |> json_response(:ok)

      assert %{"data" => [], "scroll_id" => ^scroll_id} =
               conn
               |> post(Routes.search_path(conn, :create, %{"scroll_id" => scroll_id}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations with status filter", %{
      conn: conn,
      concept: concept,
      structure: structure
    } do
      domain_1 = CacheHelpers.put_domain()
      domain_2 = CacheHelpers.put_domain()

      relation =
        generate_relation(
          %{
            source_type: "business_concept",
            source_id: concept.id,
            target_type: "data_structure",
            target_id: structure.id,
            origin: "suggested",
            status: "pending"
          },
          [domain_1, domain_2]
        )

      insert(:relation, status: "approved")

      ElasticsearchMock
      |> expect(:request, fn
        _,
        :post,
        "/relations/_search",
        %{
          sort: ["_score", "updated_at"],
          from: 0,
          query: query
        },
        _ ->
          assert %{bool: %{must: %{term: %{"status" => "pending"}}}} == query

          SearchHelpers.hits_response([relation])
      end)

      assert %{"data" => _} =
               conn
               |> post(
                 Routes.search_path(conn, :create, %{"filters" => %{"status" => ["pending"]}})
               )
               |> json_response(:ok)
    end
  end

  describe "POST /api/relations/filters" do
    @tag authentication: [role: "admin"]
    test "lists all filters", %{conn: conn} do
      aggs = %{
        "foo" => %{
          "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
        }
      }

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/relations/_search", %{query: query}, _ ->
        assert query == %{bool: %{must: %{match_all: %{}}}}
        SearchHelpers.aggs_response(aggs)
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.search_path(conn, :filters, %{}))
               |> json_response(:ok)

      assert %{"foo" => %{"values" => ["bar", "baz"]}} = data
    end
  end

  describe "POST /api/relations/reindex" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} can reindex", %{conn: conn} do
        assert conn
               |> get(Routes.search_path(conn, :reindex_all))
               |> response(:accepted)
      end
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "user whith permissions is unauthorized", %{
      conn: conn
    } do
      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> get(Routes.search_path(conn, :reindex_all))
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "user without permissions is unauthorized", %{
      conn: conn
    } do
      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> get(Routes.search_path(conn, :reindex_all))
               |> json_response(:forbidden)
    end
  end

  defp generate_relation(attrs) do
    generate_relation(attrs, [CacheHelpers.put_domain(), CacheHelpers.put_domain()])
  end

  defp generate_relation(attrs, [domain_1, domain_2]) do
    relation_attrs =
      %{
        source_type: "business_concept",
        target_type: "data_structure",
        deleted_at: nil
      }
      |> Map.merge(attrs)
      |> Keyword.new()

    :relation
    |> insert(relation_attrs)
    |> Map.put(:source_data, %{name: "Source", domain_ids: [domain_1.id]})
    |> Map.put(:target_data, %{name: "Target", domain_ids: [domain_2.id]})
  end
end
