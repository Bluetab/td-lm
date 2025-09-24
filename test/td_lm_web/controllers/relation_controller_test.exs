defmodule TdLmWeb.RelationControllerTest do
  use TdLmWeb.ConnCase

  import TdLm.TestOperators

  alias TdLm.Repo
  alias TdLm.Resources.Relation

  setup %{conn: conn} do
    start_supervised!(TdLm.Cache.LinkLoader)
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "search" do
    @tag authentication: [role: "admin"]
    test "search all relations", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "search all relations with status approved or nil", %{conn: conn} do
      %{source_id: approved_source_id} =
        insert(:relation,
          source_type: "business_concept",
          target_type: "data_field",
          status: "approved"
        )

      %{source_id: nil_source_id} =
        insert(:relation,
          source_type: "business_concept",
          target_type: "data_field",
          status: nil
        )

      insert(:relation,
        source_type: "business_concept",
        target_type: "data_field",
        status: "rejected"
      )

      insert(:relation,
        source_type: "business_concept",
        target_type: "data_field",
        status: "pending"
      )

      assert %{"data" => relations} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> json_response(:ok)

      assert relations |||
               [
                 %{"source_id" => approved_source_id},
                 %{"source_id" => nil_source_id}
               ]
    end

    @tag authentication: [role: "admin"]
    test "includes tag and tags (legacy) in response", %{conn: conn} do
      %{id: tag_id, value: tag_value} = tag = insert(:tag)
      tag_id_value = %{"id" => tag_id, "value" => tag_value}
      insert(:relation, tag: tag)

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> json_response(:ok)

      assert [%{"tags" => [^tag_id_value], "tag" => ^tag_id_value, "tag_id" => ^tag_id}] =
               data
    end

    @tag authentication: [role: "admin"]
    test "includes updated_at in response", %{conn: conn} do
      %{updated_at: updated_at} = insert(:relation)

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> json_response(:ok)

      assert [%{"updated_at" => ts}] = data
      assert ts == DateTime.to_iso8601(updated_at)
    end

    @tag authentication: [role: "admin"]
    test "includes nil origin in response", %{conn: conn} do
      insert(:relation)

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> json_response(:ok)

      assert [%{"origin" => nil}] = data
    end

    @tag authentication: [role: "admin"]
    test "includes origin with value in response", %{conn: conn} do
      origin = "test_origin"
      insert(:relation, origin: origin)

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> json_response(:ok)

      assert [%{"origin" => ^origin}] = data
    end
  end

  describe "search relation when user has no permissions" do
    @tag authentication: [user_name: "not_an_admin"]
    test "search all relations", %{conn: conn} do
      insert(:relation, source_type: "ingest")

      assert %{"data" => []} =
               conn
               |> post(Routes.relation_path(conn, :search, %{}))
               |> json_response(:ok)
    end
  end

  describe "search relations with source/target of type business concept" do
    setup do
      tag = insert(:tag)
      source = %{"id" => "141", "name" => "src_en", "version" => "2", "business_concept_id" => 14}
      target = %{"id" => "131", "name" => "tgt_en", "version" => "1", "business_concept_id" => 13}
      context = %{"source" => source, "target" => target}

      source_i8n = %{
        "es" => %{
          "name" => "src_es",
          "content" => %{}
        }
      }

      target_i8n = %{
        "es" => %{
          "name" => "tgt_es",
          "content" => %{}
        }
      }

      insert(:relation,
        source_type: "business_concept",
        source_id: source["business_concept_id"],
        target_type: "business_concept",
        target_id: target["business_concept_id"],
        context: context,
        tag: tag
      )

      put_concept_cache(Map.put(source, "i18n", source_i8n))
      put_concept_cache(Map.put(target, "i18n", target_i8n))

      [source: source, target: target, tag: tag]
    end

    @tag authentication: [role: "admin"]
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
                   "source" => %{"version_id" => ^src_version_id, "name" => "src_en"},
                   "target" => %{"version_id" => ^tgt_version_id, "name" => "tgt_en"}
                 }
               }
             ] = data
    end

    @tag authentication: [role: "admin"]
    test "includes tag and tags (legacy) in response with resource params",
         %{conn: conn, target: target, tag: %{id: tag_id, value: tag_value}} do
      tag_id_value = %{"id" => tag_id, "value" => tag_value}

      params = %{
        "resource_id" => target["business_concept_id"],
        "resource_type" => "business_concept",
        "related_to_type" => "business_concept"
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :search, params))
               |> json_response(:ok)

      assert [%{"tags" => [^tag_id_value], "tag" => ^tag_id_value, "tag_id" => ^tag_id}] =
               data
    end

    @tag authentication: [role: "admin"]
    test "get last version_id of business_concept in a relation between business concepts created with a previous target version with lang",
         %{conn: conn, source: source, target: target} do
      params = %{
        "resource_id" => target["business_concept_id"],
        "resource_type" => "business_concept",
        "related_to_type" => "business_concept"
      }

      assert %{"data" => data} =
               conn
               |> put_req_header("accept-language", "es")
               |> post(Routes.relation_path(conn, :search, params))
               |> json_response(:ok)

      src_version_id = source["id"]
      tgt_version_id = target["id"]

      assert [
               %{
                 "context" => %{
                   "source" => %{"version_id" => ^src_version_id, "name" => "src_es"},
                   "target" => %{"version_id" => ^tgt_version_id, "name" => "tgt_es"}
                 }
               }
             ] = data
    end
  end

  describe "search relations with status" do
    for status <- ["approved", nil] do
      @tag authentication: [role: "admin"]
      @tag status: status
      test "search relations with status #{if is_nil(status), do: "nil", else: status}",
           %{conn: conn, status: status} do
        %{source_id: source_id} =
          insert(:relation,
            source_type: "business_concept",
            target_type: "data_field",
            status: status
          )

        params = %{
          "resource_id" => source_id,
          "resource_type" => "business_concept",
          "related_to_type" => "data_field"
        }

        assert %{"data" => [link]} =
                 conn
                 |> post(Routes.relation_path(conn, :search, params))
                 |> json_response(:ok)

        assert link["source_id"] == source_id
      end
    end

    for status <- ["rejected", "pending"] do
      @tag authentication: [role: "admin"]
      @tag status: status
      test "return empty response relations with status #{status}",
           %{conn: conn, status: status} do
        %{source_id: source_id} =
          insert(:relation,
            source_type: "business_concept",
            target_type: "data_field",
            status: status
          )

        params = %{
          "resource_id" => source_id,
          "resource_type" => "business_concept",
          "related_to_type" => "data_field"
        }

        assert %{"data" => []} =
                 conn
                 |> post(Routes.relation_path(conn, :search, params))
                 |> json_response(:ok)
      end
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

    @tag authentication: [role: "admin"]
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
    @tag authentication: [role: "admin"]
    test "get relation between ingests", %{conn: conn} do
      %{source_id: source_id} =
        insert(:relation,
          source_type: "ingest",
          target_type: "ingest",
          target_id: System.unique_integer([:positive]),
          source_id: System.unique_integer([:positive])
        )

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
    @tag authentication: [role: "admin"]
    test "lists all relations", %{conn: conn} do
      Enum.each(1..3, fn _ -> insert(:relation) end)

      assert %{"data" => relations} =
               conn
               |> get(Routes.relation_path(conn, :index))
               |> json_response(:ok)

      assert Enum.count(relations) == 3
    end

    @tag authentication: [role: "admin"]
    test "list all relations includes tag and tags (legacy) in response", %{conn: conn} do
      %{id: tag_id} = tag = insert(:tag)
      tag_id_value = %{"id" => tag_id, "value" => tag.value}
      insert(:relation, tag: tag)

      assert %{"data" => relations} =
               conn
               |> get(Routes.relation_path(conn, :index))
               |> json_response(:ok)

      assert Enum.count(relations) == 1

      assert [%{"tags" => [^tag_id_value], "tag" => ^tag_id_value, "tag_id" => ^tag_id}] =
               relations
    end

    @tag authentication: [role: "admin"]
    test "lists empty relations", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(Routes.relation_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "always return list relations with status approved or nil", %{conn: conn} do
      %{id: approved_id} =
        insert(:relation,
          source_type: "business_concept",
          target_type: "data_field",
          status: "approved"
        )

      insert(:relation,
        target_type: "data_field",
        source_type: "business_concept",
        status: "pending"
      )

      insert(:relation,
        target_type: "data_field",
        source_type: "business_concept",
        status: "rejected"
      )

      %{id: nil_id} =
        insert(:relation, target_type: "data_field", source_type: "business_concept", status: nil)

      assert %{"data" => relations} =
               conn
               |> get(Routes.relation_path(conn, :index))
               |> json_response(:ok)

      assert relations ||| [%{"id" => approved_id}, %{"id" => nil_id}]
    end

    @tag authentication: [role: "admin"]
    test "list relations with specific status", %{conn: conn} do
      insert(:relation,
        source_type: "business_concept",
        target_type: "data_field",
        status: "approved"
      )

      %{id: pending_id_1} =
        insert(:relation,
          target_type: "data_field",
          source_type: "business_concept",
          status: "pending"
        )

      %{id: pending_id_2} =
        insert(:relation,
          target_type: "data_field",
          source_type: "business_concept",
          status: "pending"
        )

      insert(:relation, target_type: "data_field", source_type: "business_concept", status: nil)

      assert %{"data" => relations} =
               conn
               |> get(Routes.relation_path(conn, :index, %{"status" => "pending"}))
               |> json_response(:ok)

      assert relations ||| [%{"id" => pending_id_1}, %{"id" => pending_id_2}]
    end
  end

  describe "show" do
    setup tags do
      create_hierarchy(tags)
    end

    @tag authentication: [permissions: ["view_approval_pending_business_concepts"]]
    test "relation when user has permissions", %{
      conn: conn,
      concept: concept
    } do
      %{id: id} = insert(:relation, source_id: concept.id, source_type: "business_concept")

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> get(Routes.relation_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "relation with tag and tags (legacy) in response", %{
      conn: conn,
      concept: concept
    } do
      %{id: tag_id} = tag = insert(:tag)
      tag_id_value = %{"id" => tag_id, "value" => tag.value}

      %{id: id} =
        insert(:relation, source_id: concept.id, source_type: "business_concept", tag: tag)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "tags" => [^tag_id_value],
                 "tag" => ^tag_id_value,
                 "tag_id" => ^tag_id
               }
             } =
               conn
               |> get(Routes.relation_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "relation when user has permissions over shared domain", %{
      conn: conn,
      claims: claims,
      concept: %{shared_to_ids: [shared_id], id: concept_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        "view_approval_pending_business_concepts" => [shared_id]
      })

      %{id: id} = insert(:relation, source_id: concept_id, source_type: "business_concept")

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> get(Routes.relation_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "unauthorized when user has not permissions", %{conn: conn, concept: concept} do
      %{id: id} = insert(:relation, source_id: concept.id, source_type: "business_concept")

      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> get(Routes.relation_path(conn, :show, id))
               |> json_response(:forbidden)
    end
  end

  describe "create relation" do
    setup :create_hierarchy

    @tag authentication: [role: "admin"]
    test "renders relation when data is valid", %{conn: conn} do
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

    @tag authentication: [role: "admin"]
    test "renders relation when data is valid with tag and tags (legacy)", %{conn: conn} do
      %{id: tag_id} = tag = insert(:tag)
      tag_id_value = %{"id" => tag_id, "value" => tag.value}

      params =
        :relation
        |> string_params_for()
        |> Map.put(:tag_ids, [tag_id])

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:created)

      assert %{
               "tags" => [^tag_id_value],
               "tag" => ^tag_id_value,
               "tag_id" => ^tag_id
             } = data
    end

    @tag authentication: [role: "admin"]
    test "creates relation with default nil origin as default", %{conn: conn} do
      params = %{
        "context" => %{},
        "source_id" => 123,
        "source_type" => "business_concept",
        "target_id" => 321,
        "target_type" => "data_structure"
      }

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:created)

      assert %{origin: nil} = Repo.one(Relation, id: id)
    end

    @tag authentication: [role: "admin"]
    test "creates relation with origin value", %{conn: conn} do
      params = %{
        "context" => %{},
        "source_id" => 123,
        "source_type" => "business_concept",
        "target_id" => 321,
        "target_type" => "data_structure",
        "origin" => "test_origin"
      }

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:created)

      assert %{origin: "test_origin"} = Repo.one(Relation, id: id)
    end

    @tag authentication: [role: "admin"]
    test "creates relation with status nil", %{conn: conn} do
      params = %{
        "context" => %{},
        "source_id" => 123,
        "source_type" => "business_concept",
        "target_id" => 321,
        "target_type" => "data_structure"
      }

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:created)

      assert %{status: nil} = Repo.one(Relation, id: id)
    end

    for status <- ["approved", "rejected"] do
      @tag authentication: [role: "admin"], status: status
      test "error on create relation with invalid #{status} status", %{conn: conn, status: status} do
        params = %{
          "context" => %{},
          "source_id" => 123,
          "source_type" => "business_concept",
          "target_id" => 321,
          "target_type" => "data_structure",
          "status" => status
        }

        assert %{"errors" => errors} =
                 conn
                 |> post(Routes.relation_path(conn, :create), relation: params)
                 |> json_response(:unprocessable_entity)

        assert %{"status" => ["is invalid"]} == errors
      end
    end

    for status <- ["pending", nil] do
      @tag authentication: [role: "admin"], status: status
      test "creates relation with valid #{if is_nil(status), do: "nil", else: status} status", %{
        conn: conn,
        status: status
      } do
        params = %{
          "context" => %{},
          "source_id" => 123,
          "source_type" => "business_concept",
          "target_id" => 321,
          "target_type" => "data_structure",
          "status" => status
        }

        assert %{"data" => %{"id" => id}} =
                 conn
                 |> post(Routes.relation_path(conn, :create), relation: params)
                 |> json_response(:created)

        assert %{status: ^status} = Repo.one(Relation, id: id)
      end
    end

    @tag authentication: [role: "admin"]
    test "error when creates relation with invalid status", %{conn: conn} do
      params = %{
        "context" => %{},
        "source_id" => 123,
        "source_type" => "business_concept",
        "target_id" => 321,
        "target_type" => "data_structure",
        "status" => "invalid_status"
      }

      assert %{"errors" => %{"status" => ["is invalid"]}} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [permissions: ["manage_business_concept_links"]]
    test "renders relation when user has permission over domain", %{
      conn: conn,
      concept: %{id: id}
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
               |> json_response(:created)

      assert %{
               "source_id" => ^source_id,
               "source_type" => ^source_type,
               "target_id" => ^target_id,
               "target_type" => ^target_type,
               "context" => ^context,
               "tags" => []
             } = data
    end

    @tag authentication: [permissions: ["link_implementation_business_concept"]]
    test "can create implementation_ref link when user has permissions", %{
      conn: conn,
      concept: concept
    } do
      %{
        "context" => context,
        "source_id" => source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type
      } =
        params =
        string_params_for(:relation,
          source_id: System.unique_integer([:positive]),
          source_type: "implementation_ref",
          target_id: concept.id,
          target_type: "business_concept"
        )

      assert %{"data" => data} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
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

    @tag authentication: [permissions: ["manage_business_concept_links"]]
    test "renders relation when user has permission over shared domain", %{
      conn: conn,
      concept: %{id: id}
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

    @tag authentication: [user_name: "not_an_admin"]
    test "error when user has not permissions to create a relation", %{conn: conn} do
      params = string_params_for(:relation, source_type: "ingest")

      assert %{"errors" => _} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "error when user has not permissions to create a implementation_ref link", %{conn: conn} do
      params =
        string_params_for(:relation,
          source_type: "implementation_ref",
          target_type: "business_concept"
        )

      assert %{"errors" => _} =
               conn
               |> post(Routes.relation_path(conn, :create), relation: params)
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
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

    @tag authentication: [user_name: "not_an_admin"]
    test "error when user has not permissions to create a relation", %{
      conn: conn,
      relation: relation
    } do
      assert %{"errors" => _} =
               conn
               |> delete(Routes.relation_path(conn, :delete, relation))
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "deletes chosen relation", %{conn: conn, relation: relation} do
      assert conn
             |> delete(Routes.relation_path(conn, :delete, relation))
             |> response(:no_content)
    end
  end

  defp create_hierarchy(context) do
    %{id: domain_id} = Map.get(context, :domain, CacheHelpers.put_domain())
    %{id: shared_id} = CacheHelpers.put_domain()

    concept =
      CacheHelpers.put_concept(
        domain_id: domain_id,
        name: "xyz",
        shared_to_ids: [shared_id]
      )

    [concept: concept]
  end

  defp put_concept_cache(%{
         "business_concept_id" => id,
         "id" => business_concept_version_id,
         "name" => name,
         "i18n" => i18n
       }) do
    CacheHelpers.put_concept(
      id: id,
      domain_id: 1,
      name: name,
      business_concept_version_id: business_concept_version_id,
      i18n: i18n
    )
  end
end
