defmodule TdLm.SearchTest do
  use TdLmWeb.ConnCase

  import Mox

  alias TdLM.Search

  @permissions ["manage_business_concept_links", "link_data_structure"]

  @aggs %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup :verify_on_exit!

  describe "get_filter_values/2" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "searches and returns filters for #{role} account", %{claims: claims} do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/relations/_search", %{aggs: _, query: query, size: 0}, _ ->
            assert %{bool: %{must: %{match_all: %{}}}} == query
            SearchHelpers.aggs_response(@aggs)
        end)

        assert {:ok, %{"foo" => %{values: ["bar", "baz"]}}} =
                 Search.get_filter_values(claims, %{})
      end
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "searches and returns filters for non admin user account", %{
      claims: claims,
      domain: %{id: domain_id}
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/relations/_search", %{aggs: _, query: query, size: 0}, _ ->
          assert %{bool: %{must: %{term: %{"domain_ids" => ^domain_id}}}} = query

          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok,
              %{
                "foo" => %{
                  values: ["bar", "baz"]
                }
              }} = Search.get_filter_values(claims, %{})
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "include filters from request parameters", %{claims: claims, domain: %{id: domain_id}} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/relations/_search", %{aggs: _, query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     must: [
                       %{term: %{"foo" => "bar"}},
                       %{term: %{"domain_ids" => ^domain_id}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response(@aggs)
      end)

      params = %{"filters" => %{"foo" => ["bar"]}}

      assert {:ok,
              %{
                "foo" => %{
                  values: ["bar", "baz"],
                  buckets: [%{"key" => "bar"}, %{"key" => "baz"}]
                }
              }} =
               Search.get_filter_values(claims, params)
    end
  end

  describe "search/2" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "searches relations for #{role} account", %{claims: claims} do
        %{"relations" => relations} = create_relations()

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
            SearchHelpers.hits_response(relations)
        end)

        assert %{total: 2, results: [_, _]} = Search.search(%{}, claims)
      end
    end

    @tag authentication: [role: "user", permissions: @permissions]
    test "search relations for non admin user account", %{
      claims: claims,
      domain: %{id: user_domain_id} = domain
    } do
      domains = [
        domain,
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain()
      ]

      %{"relations" => relations} = create_relations(domains)

      %{
        id: relation_id,
        origin: relation_origin,
        status: relation_status,
        source_id: relation_source_id,
        source_type: relation_source_type,
        source_data: %{name: relation_source_name, domain_ids: relation_source_domain_ids},
        target_id: relation_target_id,
        target_type: relation_target_type,
        target_data: %{name: relation_target_name, domain_ids: relation_target_domain_ids}
      } = relation = List.first(relations)

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
          assert %{bool: %{must: %{term: %{"domain_ids" => ^user_domain_id}}}} = query

          SearchHelpers.hits_response([relation])
      end)

      domains_ids = Enum.uniq(relation_source_domain_ids ++ relation_target_domain_ids)

      assert %{
               total: 1,
               results: [
                 %{
                   "domain_ids" => ^domains_ids,
                   "id" => ^relation_id,
                   "origin" => ^relation_origin,
                   "status" => ^relation_status,
                   "source_domain_ids" => ^relation_source_domain_ids,
                   "source_id" => ^relation_source_id,
                   "source_name" => ^relation_source_name,
                   "source_type" => ^relation_source_type,
                   "target_domain_ids" => ^relation_target_domain_ids,
                   "target_id" => ^relation_target_id,
                   "target_name" => ^relation_target_name,
                   "target_type" => ^relation_target_type
                 }
               ]
             } = Search.search(%{}, claims)
    end

    @tag authentication: [role: "user"]
    test "returns empty for non admin user account", %{claims: claims} do
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
          assert %{bool: %{must: %{match_none: %{}}}} = query

          SearchHelpers.hits_response([])
      end)

      assert %{total: 0, results: []} = Search.search(%{}, claims)
    end

    @tag authentication: [role: "admin"]
    test "includes scroll_id in response", %{claims: claims} do
      %{"relations" => relations} = create_relations()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/relations/_search", _, [params: %{"scroll" => "1m"}] ->
        SearchHelpers.scroll_response(relations, 7)
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", %{"scroll_id" => "some_scroll_id"}, _ ->
        SearchHelpers.scroll_response([], 7)
      end)

      %{total: 7, results: [_, _], scroll_id: scroll_id} =
        Search.search(%{"scroll" => "1m"}, claims)

      %{total: 7, results: [], scroll_id: ^scroll_id} =
        Search.search(%{"scroll_id" => scroll_id}, claims)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations with status filter", %{claims: claims} do
      %{"relations" => relations} = create_relations()
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

          SearchHelpers.hits_response(relations)
      end)

      assert %{
               total: 2,
               results: [_, _]
             } = Search.search(%{"filters" => %{"status" => ["pending"]}}, claims)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations with taxonomy filter", %{claims: claims} do
      %{"relations" => [relation | _], "domains" => [%{id: domain_id} | _]} = create_relations()

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

      assert %{
               total: 1,
               results: [_]
             } = Search.search(%{"filters" => %{"taxonomy" => [domain_id]}}, claims)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all relations for origin filter", %{claims: claims} do
      %{"domains" => [source_domain, target_domain | _]} = create_relations()

      relation =
        insert(:relation, origin: "suggested")
        |> Map.merge(%{
          source_data: %{domain_ids: [source_domain.id], name: "Source"},
          target_data: %{domain_ids: [target_domain.id], name: "Target"}
        })

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
          assert %{bool: %{must: %{term: %{"origin" => "suggested"}}}} = query

          SearchHelpers.hits_response([relation])
      end)

      assert %{
               total: 1,
               results: [_]
             } = Search.search(%{"filters" => %{"origin" => ["suggested"]}}, claims)
    end

    def create_relations do
      create_relations([
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain(),
        CacheHelpers.put_domain()
      ])
    end

    def create_relations(domains) do
      relations =
        Enum.map(1..2, fn i ->
          # domain_1, domain_3
          source_domain = Enum.at(domains, (i - 1) * 2)
          # domain_2, domain_4
          target_domain = Enum.at(domains, (i - 1) * 2 + 1)

          :relation
          |> insert(status: "pending")
          |> Map.merge(%{
            source_data: %{domain_ids: [source_domain.id], name: "Source"},
            target_data: %{domain_ids: [target_domain.id], name: "Target"}
          })
        end)

      %{"relations" => relations, "domains" => domains}
    end
  end
end
