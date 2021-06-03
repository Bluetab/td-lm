defmodule TdLmWeb.RelationControllerTest do
  use TdLmWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.{ConceptCache, TaxonomyCache}

  setup_all do
    start_supervised(TdLm.Cache.LinkLoader)
    :ok
  end

  setup %{conn: conn} do
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "search" do
    @tag :admin_authenticated
    test "search all relations", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => []} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> validate_resp_schema(schema, "RelationsResponse")
               |> json_response(:ok)
    end
  end

  describe "search relation when user has no permissions" do
    @tag authenticated_user: "non_admin"
    test "search all relations", %{conn: conn, swagger_schema: schema} do
      insert(:relation, source_type: "ingest")

      assert %{"data" => []} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> validate_resp_schema(schema, "RelationsResponse")
               |> json_response(:ok)
    end
  end

  describe "search relations with source/target of type business concept" do
    setup do
      source = %{"id" => "141", "name" => "src", "version" => "2", "business_concept_id" => "14"}
      target = %{"id" => "131", "name" => "tgt", "version" => "1", "business_concept_id" => "13"}
      context = %{"source" => source, "target" => target}

      insert(:relation,
        source_type: "business_concept",
        source_id: source["business_concept_id"],
        target_type: "business_concept",
        target_id: target["business_concept_id"],
        context: context
      )

      put_concept_cache(source)
      put_concept_cache(target)
      [source: source, target: target]
    end

    @tag :admin_authenticated
    test "get last version_id of business_concept in a relation between business concepts created with a previous target version",
         %{conn: conn, source: source, target: target} do
      params = %{
        "resource_id" => target["business_concept_id"],
        "resource_type" => "business_concept",
        "related_to_type" => "business_concept"
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :search, params))
               |> json_response(:ok)

      src_version_id = source["id"]
      tgt_version_id = target["id"]

      assert [
               %{
                 "context" => %{
                   "source" => %{"version_id" => ^src_version_id, "name" => "src"},
                   "target" => %{"version_id" => ^tgt_version_id, "name" => "tgt"}
                 }
               }
             ] = data
    end
  end

  describe "search data_field linked to business concept" do
    setup do
      [
        context: %{
          "target" => %{
            "field" => "ADDRESS",
            "group" => "NEW_CONN",
            "structure" => "PERSONS [DBO]",
            "structure_id" => 1,
            "system" => "Microstrategy"
          }
        }
      ]
    end

    @tag :admin_authenticated
    test "get relation without version id when target is data_field", %{
      conn: conn,
      context: context
    } do
      %{source_id: source_id} =
        insert(:relation,
          context: context,
          source_type: "business_concept",
          target_type: "data_field"
        )

      params = %{
        "resource_id" => source_id,
        "resource_type" => "business_concept",
        "related_to_type" => "data_field"
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :search, params))
               |> json_response(:ok)

      assert [%{"context" => ^context} | _] = data
    end
  end

  describe "search ingest to ingest relations" do
    @tag :admin_authenticated
    test "get relation between ingests", %{conn: conn} do
      %{source_id: source_id} = insert(:relation, source_type: "ingest", target_type: "ingest")

      params = %{
        "resource_id" => source_id,
        "resource_type" => "ingest",
        "related_to_type" => "ingest"
      }

      assert %{"data" => [_]} =
               conn
               |> post(Routes.relation_path(conn, :search, params))
               |> json_response(:ok)
    end
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all relations", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => []} =
               conn
               |> get(Routes.relation_path(conn, :index))
               |> validate_resp_schema(schema, "RelationsResponse")
               |> json_response(:ok)
    end
  end

  describe "create relation" do
    setup tags do
      domain = %{
        id: System.unique_integer([:positive]),
        name: "foo",
        external_id: "bar",
        updated_at: DateTime.utc_now()
      }

      shared = %{
        id: System.unique_integer([:positive]),
        name: "bar",
        external_id: "baz",
        updated_at: DateTime.utc_now()
      }

      concept = %{
        id: Integer.to_string(System.unique_integer([:positive])),
        domain_id: domain.id,
        name: "xyz",
        business_concept_version_id: System.unique_integer([:positive]),
        shared_to_ids: [shared.id]
      }

      ConceptCache.put(concept)
      TaxonomyCache.put_domain(domain)
      TaxonomyCache.put_domain(shared)

      on_exit(fn ->
        ConceptCache.delete(concept.id)
        TaxonomyCache.delete_domain(domain.id)
        TaxonomyCache.delete_domain(shared.id)
      end)

      case tags do
        %{shared_permissions: [_ | _] = permissions, claims: %{user_id: user_id}} ->
          create_acl_entry(user_id, "domain", shared.id, permissions)

        %{permissions: [_ | _] = permissions, claims: %{user_id: user_id}} ->
          create_acl_entry(user_id, "domain", domain.id, permissions)

        _ ->
          :ok
      end

      [concept: concept]
    end

    @tag :admin_authenticated
    test "renders relation when data is valid", %{conn: conn, swagger_schema: schema} do
      %{
        "context" => context,
        "source_id" => source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type
      } = params = string_params_for(:relation)

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> validate_resp_schema(schema, "RelationResponse")
               |> json_response(:created)

      assert %{
               "id" => _id,
               "source_id" => ^source_id,
               "source_type" => ^source_type,
               "target_id" => ^target_id,
               "target_type" => ^target_type,
               "context" => ^context,
               "tags" => []
             } = data
    end

    @tag authenticated_user: "non_admin"
    @tag permissions: [:manage_business_concept_links]
    test "renders relation when user has permission over domain", %{
      conn: conn,
      concept: %{id: id},
      swagger_schema: schema
    } do
      %{
        "context" => context,
        "source_id" => source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type
      } = params = string_params_for(:relation, source_id: id, source_type: "business_concept")

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> validate_resp_schema(schema, "RelationResponse")
               |> json_response(:created)

      assert %{
               "id" => _id,
               "source_id" => ^source_id,
               "source_type" => ^source_type,
               "target_id" => ^target_id,
               "target_type" => ^target_type,
               "context" => ^context,
               "tags" => []
             } = data
    end

    @tag authenticated_user: "non_admin"
    @tag shared_permissions: [:manage_business_concept_links]
    test "renders relation when user has permission over shared domain", %{
      conn: conn,
      concept: %{id: id},
      swagger_schema: schema
    } do
      %{
        "context" => context,
        "source_id" => source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type
      } = params = string_params_for(:relation, source_id: id, source_type: "business_concept")

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> validate_resp_schema(schema, "RelationResponse")
               |> json_response(:created)

      assert %{
               "id" => _id,
               "source_id" => ^source_id,
               "source_type" => ^source_type,
               "target_id" => ^target_id,
               "target_type" => ^target_type,
               "context" => ^context,
               "tags" => []
             } = data
    end

    @tag authenticated_user: "non_admin"
    test "error when user has not permissions to create a relation", %{conn: conn} do
      params = string_params_for(:relation, source_type: "ingest")

      assert %{"errors" => _} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:forbidden)
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      params = %{"source_id" => nil}

      assert %{"errors" => _} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:bad_request)

      params = %{"source_id" => nil, "source_type" => "foo"}

      assert %{"errors" => _} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:unprocessable_entity)
    end
  end

  describe "delete relation" do
    setup do
      [relation: insert(:relation, source_type: "ingest")]
    end

    @tag authenticated_user: "non_admin"
    test "error when user has not permissions to create a relation", %{
      conn: conn,
      relation: relation
    } do
      assert %{"errors" => _} =
               conn
               |> delete(Routes.relation_path(conn, :delete, relation))
               |> json_response(:forbidden)
    end

    @tag :admin_authenticated
    test "deletes chosen relation", %{conn: conn, relation: relation} do
      assert conn
             |> delete(Routes.relation_path(conn, :delete, relation))
             |> response(:no_content)
    end
  end

  defp put_concept_cache(%{
         "business_concept_id" => id,
         "id" => business_concept_version_id,
         "name" => name
       }) do
    ConceptCache.put(%{
      id: id,
      domain_id: 1,
      name: name,
      business_concept_version_id: business_concept_version_id
    })

    on_exit(fn ->
      ConceptCache.delete(id)
    end)
  end
end
