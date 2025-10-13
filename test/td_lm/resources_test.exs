defmodule TdLm.ResourcesTest do
  use TdLm.DataCase

  alias TdCache.LinkCache
  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCluster.TestHelpers.TdBgMock
  alias TdCluster.TestHelpers.TdDdMock
  alias TdCore.Search.IndexWorkerMock
  alias TdLm.Auth.Claims
  alias TdLm.Resources
  alias TdLm.Resources.Relation

  import Mox

  @stream TdCache.Audit.stream()

  setup_all do
    Redix.del!(@stream)
    [claims: build(:claims)]
  end

  setup do
    start_supervised!(TdLm.Cache.LinkLoader)

    on_exit(fn ->
      Redix.del!(@stream)
      IndexWorkerMock.clear()
    end)

    :ok
  end

  setup :verify_on_exit!

  describe "create_relation/2" do
    setup [:put_template, :put_concept]

    test "creates a relation without tag", %{claims: claims} do
      IndexWorkerMock.clear()

      %{
        "source_id" => source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type
      } = params = string_params_for(:relation)

      assert {:ok, %{relation: relation}} = Resources.create_relation(params, claims)

      assert %{
               id: id,
               source_id: ^source_id,
               source_type: ^source_type,
               target_id: ^target_id,
               target_type: ^target_type,
               context: context,
               tag_id: nil,
               tag: nil,
               tags: []
             } =
               relation

      assert context == %{}
      assert [{:reindex, :relations, [^id]}] = IndexWorkerMock.calls()
    end

    test "creates a relation with the specified tag", %{claims: claims} do
      tag_id = insert(:tag).id

      params = string_params_for(:relation) |> Map.put("tag_id", tag_id)
      assert {:ok, %{relation: relation}} = Resources.create_relation(params, claims)
      assert %{tags: [tag]} = relation
      assert tag.id == tag_id
    end

    test "publishes an audit event", %{claims: claims, concept: concept} do
      source_id = concept.id
      target_id = System.unique_integer([:positive])
      domain_ids = [concept.domain_id]

      params = %{
        source_id: source_id,
        source_type: "business_concept",
        target_id: target_id,
        target_type: "business_concept",
        context: %{}
      }

      {:ok, %{audit: event_id, relation: %Relation{source_id: ^source_id, target_id: ^target_id}}} =
        Resources.create_relation(params, claims)

      {:ok, [%{id: ^event_id, resource_id: resource_id, payload: payload}]} =
        Stream.read(:redix, @stream, transform: true)

      assert resource_id == "#{source_id}"

      assert %{"subscribable_fields" => %{"foo" => "bar"}, "domain_ids" => ^domain_ids} =
               Jason.decode!(payload)
    end

    test "publishes an audit event with tag", %{claims: claims, concept: concept} do
      tag = insert(:tag, value: %{"target_type" => "foo"})
      source_id = concept.id
      target_id = System.unique_integer([:positive])
      domain_ids = [concept.domain_id]

      params = %{
        source_id: source_id,
        source_type: "business_concept",
        target_id: target_id,
        target_type: "business_concept",
        context: %{},
        tag_id: tag.id
      }

      {:ok, %{audit: event_id, relation: %Relation{source_id: ^source_id, target_id: ^target_id}}} =
        Resources.create_relation(params, claims)

      {:ok, [%{id: ^event_id, resource_id: resource_id, payload: payload}]} =
        Stream.read(:redix, @stream, transform: true)

      assert resource_id == "#{source_id}"

      assert %{
               "subscribable_fields" => %{"foo" => "bar"},
               "domain_ids" => ^domain_ids,
               "relation_types" => ["foo"]
             } =
               Jason.decode!(payload)
    end

    test "returns error and changeset if validations fail", %{claims: claims} do
      params = %{"source_id" => nil}

      assert {:error, :relation, %Ecto.Changeset{}, _} = Resources.create_relation(params, claims)
    end

    test "insert relation in cache for nil status", %{claims: claims} do
      params = string_params_for(:relation)

      assert {:ok, %{relation: %{id: id}}} = Resources.create_relation(params, claims)

      str_id = Integer.to_string(id)
      assert {:ok, %TdCache.Link{id: ^str_id}} = LinkCache.get(id)
    end

    test "do not insert relation in cache for suggested origin", %{claims: claims} do
      IndexWorkerMock.clear()

      params =
        :relation
        |> string_params_for()
        |> Map.put("origin", "suggested")
        |> Map.put("status", "pending")

      assert {:ok, %{relation: %{id: id}}} =
               Resources.create_relation(params, claims)

      assert {:ok, nil} == LinkCache.get(id)
      assert [{:reindex, :relations, [^id]}] = IndexWorkerMock.calls()
    end
  end

  describe "update_relations_status/2" do
    setup %{claims: claims} do
      %{id: domain_id} = CacheHelpers.put_domain()

      CacheHelpers.put_session_permissions(claims, domain_id, [:manage_business_concept_links])

      %{id: concept_id} =
        CacheHelpers.put_concept(
          domain_id: domain_id,
          type: "business_concept",
          name: "concept_name_1"
        )

      %{id: non_permission_concept_id} =
        CacheHelpers.put_concept(
          domain_id: domain_id + 1,
          type: "business_concept",
          name: "concept_name_2"
        )

      %{id: structure_id} = CacheHelpers.put_structure()

      common_options = [
        source_type: "business_concept",
        source_id: concept_id,
        target_type: "data_structure",
        target_id: structure_id
      ]

      %{id: pending_status_id} =
        insert(
          :relation,
          Keyword.merge(common_options, status: "pending", context: %{"status" => "pending"})
        )

      %{id: nil_status_id} =
        insert(
          :relation,
          Keyword.merge(common_options, status: "nil", context: %{"status" => "nil"})
        )

      %{id: approved_status_id} =
        insert(
          :relation,
          Keyword.merge(common_options, status: "approved", context: %{"status" => "approved"})
        )

      %{id: rejected_status_id} =
        insert(
          :relation,
          Keyword.merge(common_options, status: "rejected", context: %{"status" => "rejected"})
        )

      %{id: not_allowed_id} =
        insert(:relation,
          source_type: "business_concept",
          source_id: non_permission_concept_id,
          target_type: "data_structure",
          target_id: structure_id,
          status: "pending",
          context: %{"permission" => "not_allowed"}
        )

      %{id: useless_id} =
        insert(
          :relation,
          Keyword.merge(common_options, status: "pending", context: %{"avoid" => "no update"})
        )

      non_existing_id = useless_id + 1

      {:ok,
       claims: claims,
       relation_ids: [
         pending_status_id,
         nil_status_id,
         approved_status_id,
         rejected_status_id,
         not_allowed_id,
         non_existing_id
       ]}
    end

    test "returns empty for non existing relations", %{
      claims: claims,
      relation_ids: relations_ids
    } do
      IndexWorkerMock.clear()

      [
        _pending_status_id,
        _nil_status_id,
        _approved_status_id,
        _relation_id4,
        _relation_id5,
        not_existing_id
      ] = relations_ids

      params = %{
        "relation_ids" => [not_existing_id],
        "status" => "approved"
      }

      assert {:ok, %{errors: [], relations_updated: [], audit: []}} =
               Resources.update_relations_status(params, claims)

      assert [{:reindex, :relations, []}] = IndexWorkerMock.calls()
    end

    test "returns errors for not allowed relations", %{
      claims: claims,
      relation_ids: relations_ids
    } do
      IndexWorkerMock.clear()

      [
        _pending_status_id,
        _nil_status_id,
        _approved_status_id,
        _relation_id4,
        not_allowed_id,
        _non_existing_id
      ] = relations_ids

      params = %{
        "relation_ids" => [not_allowed_id],
        "status" => "approved"
      }

      assert {:ok, %{errors: errors, relations_updated: [], audit: []}} =
               Resources.update_relations_status(params, claims)

      assert [{%{id: ^not_allowed_id}, [permissions: {"forbidden", []}]}] = errors
      assert [{:reindex, :relations, []}] = IndexWorkerMock.calls()
    end

    test "returns errors for not updatable relations", %{
      claims: claims,
      relation_ids: relations_ids
    } do
      IndexWorkerMock.clear()

      [
        _pending_status_id,
        nil_status_id,
        approved_status_id,
        rejected_status_id,
        _relation_id5,
        _non_existing_id
      ] = relations_ids

      params = %{
        "relation_ids" => [nil_status_id, approved_status_id, rejected_status_id],
        "status" => "approved"
      }

      assert {:ok, %{errors: errors, relations_updated: [], audit: []}} =
               Resources.update_relations_status(params, claims)

      assert [
               {%{id: ^nil_status_id}, [status_nil: {"is not allowed to change nil status", []}]},
               {%{id: ^approved_status_id},
                [status_approved: {"is not allowed to change approved status", []}]},
               {%{id: ^rejected_status_id},
                [status_rejected: {"is not allowed to change rejected status", []}]}
             ] = errors

      assert [{:reindex, :relations, []}] = IndexWorkerMock.calls()
    end

    for status <- ["approved", "rejected"] do
      @tag status: status
      test "updates relation status to #{status}", %{
        claims: claims,
        relation_ids: relations_ids,
        status: status
      } do
        IndexWorkerMock.clear()

        [
          pending_status_id,
          _nil_status_id,
          _approved_status_id,
          _relation_id4,
          _relation_id5,
          _non_existing_id
        ] = relations_ids

        params = %{
          "relation_ids" => [pending_status_id],
          "status" => status
        }

        assert {:ok, %{errors: [], relations_updated: [updated_relation], audit: [_]}} =
                 Resources.update_relations_status(params, claims)

        assert %{
                 id: ^pending_status_id,
                 status: ^status
               } = updated_relation

        assert [{:reindex, :relations, [^pending_status_id]}] = IndexWorkerMock.calls()
      end
    end

    test "audit relation update", %{
      claims: %{user_id: user_id} = claims,
      relation_ids: relations_ids
    } do
      IndexWorkerMock.clear()

      [
        pending_status_id,
        _nil_status_id,
        _approved_status_id,
        _relation_id4,
        _relation_id5,
        _non_existing_id
      ] = relations_ids

      params = %{
        "relation_ids" => [pending_status_id],
        "status" => "approved"
      }

      assert {:ok, %{errors: [], relations_updated: [_], audit: [audit_event]}} =
               Resources.update_relations_status(params, claims)

      str_user_id = Integer.to_string(user_id)

      assert {
               :ok,
               [
                 %{
                   id: ^audit_event,
                   payload: payload,
                   event: "relation_status_updated",
                   user_id: ^str_user_id
                 }
               ]
             } =
               Stream.read(:redix, @stream, transform: true)

      assert %{
               "id" => ^pending_status_id,
               "status" => "approved"
             } =
               Jason.decode!(payload)
    end

    test "insert relation in cache on approved", %{
      claims: claims,
      relation_ids: relations_ids
    } do
      IndexWorkerMock.clear()

      [
        pending_status_id,
        _nil_status_id,
        _approved_status_id,
        _relation_id4,
        _relation_id5,
        _non_existing_id
      ] = relations_ids

      params = %{
        "relation_ids" => [pending_status_id],
        "status" => "approved"
      }

      assert {:ok,
              %{
                errors: [],
                relations_updated: [
                  %{
                    id: id,
                    source_type: source_type,
                    source_id: source_id,
                    target_type: target_type,
                    target_id: target_id
                  }
                ],
                audit: [_]
              }} =
               Resources.update_relations_status(params, claims)

      str_id = Integer.to_string(id)
      source_key = "#{source_type}:#{source_id}"
      target_key = "#{target_type}:#{target_id}"

      assert {:ok, %{id: ^str_id, source: ^source_key, target: ^target_key}} = LinkCache.get(id)
      assert [{:reindex, :relations, [^id]}] = IndexWorkerMock.calls()
    end

    test "do not insert relation in cache on rejection", %{
      claims: claims,
      relation_ids: relations_ids
    } do
      IndexWorkerMock.clear()

      [
        pending_status_id,
        _nil_status_id,
        _approved_status_id,
        _relation_id4,
        _relation_id5,
        _non_existing_id
      ] = relations_ids

      params = %{
        "relation_ids" => [pending_status_id],
        "status" => "rejected"
      }

      assert {:ok, %{errors: [], relations_updated: [%{id: id}], audit: [_]}} =
               Resources.update_relations_status(params, claims)

      assert {:ok, nil} = LinkCache.get(id)
      assert [{:reindex, :relations, [^id]}] = IndexWorkerMock.calls()
    end
  end

  describe "delete_relation/2" do
    setup [:put_template, :put_concept]

    test "delete_relation/2 deletes", %{claims: claims} do
      relation = insert(:relation)

      assert {:ok, %{relation: %{id: id} = relation}} =
               Resources.delete_relation(relation, claims)

      assert %{__meta__: %{state: :deleted}} = relation
      assert [{:delete, :relations, [^id]}] = IndexWorkerMock.calls()
    end

    test "publishes an audit event", %{
      claims: claims,
      concept: %{id: concept_id, domain_id: domain_id}
    } do
      domain_ids = [domain_id]
      relation = insert(:relation, source_type: "business_concept", source_id: concept_id)
      assert {:ok, %{audit: event_id}} = Resources.delete_relation(relation, claims)

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert %{"domain_ids" => ^domain_ids} = Jason.decode!(payload)
    end
  end

  test "list_relations/0 returns all relations" do
    relation = insert(:relation)
    assert Resources.list_relations() == [relation]
  end

  test "list_relations/1 returns the relations filter by the provided params" do
    tag_1 = insert(:tag, value: %{"type" => "First type", "target_type" => "foo"})
    tag_2 = insert(:tag, value: %{"type" => "Second type"})
    tag_3 = insert(:tag, value: %{"type" => "Third type"})

    relation_1 = insert(:relation, tag: tag_1, source_type: "new type")
    relation_2 = insert(:relation, tag: tag_2)
    relation_3 = insert(:relation, tag: tag_3)

    relations = Resources.list_relations(%{"value" => %{"type" => ["First type", "Second type"]}})
    assert_lists_equal(relations, [relation_1, relation_2])

    relations = Resources.list_relations(%{"value" => %{"type" => "Third type"}})
    assert_lists_equal(relations, [relation_3])

    relations =
      Resources.list_relations(%{
        "value" => %{"type" => ["First type", "Second type"]},
        "source_type" => "new type"
      })

    assert_lists_equal(relations, [relation_1])
  end

  test "list_relations/1 filters by pagination parameters" do
    ts = DateTime.utc_now()

    relations =
      Enum.map(10..1//-1, fn i -> insert(:relation, updated_at: DateTime.add(ts, -i, :second)) end)

    {%{id: min_id}, %{id: max_id}} = Enum.min_max_by(relations, & &1.id)
    assert_lists_equal(relations, Resources.list_relations(%{"min_id" => min_id}))
    assert [%{id: ^max_id}] = Resources.list_relations(%{"min_id" => max_id})

    {%{updated_at: min_ts}, %{updated_at: max_ts}} =
      Enum.min_max_by(relations, & &1.updated_at, DateTime)

    assert_lists_equal(relations, Resources.list_relations(%{"since" => min_ts}))
    assert [%{updated_at: ^max_ts}] = Resources.list_relations(%{"since" => max_ts})

    assert_lists_equal(Enum.take(relations, 5), Resources.list_relations(%{"limit" => 5}))
  end

  test "get_relation!/1 returns the relation with given id" do
    relation = insert(:relation)
    assert Resources.get_relation!(relation.id) == relation
  end

  test "get_relation!/1 returns the relation with given id with tag" do
    tag = insert(:tag)
    relation = insert(:relation, tag: tag)
    assert Resources.get_relation!(relation.id) == relation
  end

  describe "create_tag/2" do
    test "creates a tag", %{claims: claims} do
      %{"value" => value} = params = string_params_for(:tag)
      assert {:ok, %{tag: tag}} = Resources.create_tag(params, claims)
      assert %{value: ^value} = tag
    end

    test "publishes an audit event", %{claims: claims} do
      params = string_params_for(:tag)
      assert {:ok, %{audit: event_id}} = Resources.create_tag(params, claims)
      assert {:ok, [%{id: ^event_id}]} = Stream.read(:redix, @stream, transform: true)
    end

    test "returns error and changeset if validations fail", %{claims: claims} do
      params = %{value: nil}

      assert {:error, :tag, %Ecto.Changeset{valid?: false}, _} =
               Resources.create_tag(params, claims)
    end
  end

  test "clone_relations copy relations to new implementation", %{claims: claims} do
    original_id = 7777
    cloned_id = 5555
    source_type = "implementation_ref"
    target_type = "business_concept"

    [1, 2, 3, 4]
    |> Enum.map(
      &insert(:relation,
        source_id: original_id,
        source_type: source_type,
        target_type: target_type,
        target_id: &1
      )
    )

    Resources.clone_relations(original_id, cloned_id, target_type, claims)

    assert length(
             Resources.list_relations(%{
               "target_type" => target_type,
               "source_id" => original_id
             })
           ) == 4

    assert length(
             Resources.list_relations(%{
               "target_type" => target_type,
               "source_id" => cloned_id
             })
           ) == 4
  end

  test "clone_relations copy relations to new implementation with tag", %{claims: claims} do
    original_id = 7777
    cloned_id = 5555
    source_type = "implementation_ref"
    target_type = "business_concept"
    %{id: tag_id} = tag = insert(:tag)

    insert(:relation,
      source_id: original_id,
      source_type: source_type,
      target_type: target_type,
      tag: tag
    )

    Resources.clone_relations(original_id, cloned_id, target_type, claims)

    assert [%{tag_id: ^tag_id}] =
             Resources.list_relations(%{
               "target_type" => target_type,
               "source_id" => cloned_id
             })
  end

  describe "delete_tag/2" do
    test "deletes the tag and updates it's relations", %{claims: claims} do
      tag = insert(:tag)

      relations =
        Enum.map(1..5, fn _ ->
          insert(:relation, tag: tag, updated_at: DateTime.add(DateTime.utc_now(), -1, :hour))
        end)

      assert {:ok, %{tag: tag}} = Resources.delete_tag(tag, claims)
      assert %{__meta__: %{state: :deleted}} = tag

      for relation <- Repo.all(Relation) do
        refute relation.tag_id
        source_relation = Enum.find(relations, &(&1.id == relation.id))
        DateTime.compare(source_relation.updated_at, relation.updated_at) == :lt
      end
    end

    test "publishes an audit event", %{claims: claims} do
      tag = insert(:tag)
      assert {:ok, %{audit: event_id}} = Resources.delete_tag(tag, claims)
      assert {:ok, [%{id: ^event_id}]} = Stream.read(:redix, @stream, transform: true)
    end
  end

  test "list_tags/0 returns all tags" do
    assert Resources.list_tags() == []
  end

  test "list_tags/1 filtering by several return types returns all tags" do
    %{id: id1} = tag_1 = insert(:tag, value: %{"type" => "First type", "target_type" => "Foo"})
    tag_2 = insert(:tag, value: %{"type" => "Second type"})
    insert(:tag, value: %{"type" => "Third type"})

    insert(:relation, tag: tag_1)
    insert(:relation, tag: tag_2)

    result_tags = Resources.list_tags(%{"value" => %{"type" => "First type"}})

    assert [%{id: ^id1}] = result_tags
  end

  test "get_tag!/1 returns the tag with given id" do
    tag = insert(:tag)
    assert Resources.get_tag!(tag.id) == tag
  end

  test "graph/3 gets edges and nodes with tag" do
    tag = insert(:tag)
    claims = %Claims{user_id: 1, role: "admin"}

    relations =
      Enum.map(1..10, fn id ->
        insert(:relation,
          source_type: "business_concept",
          target_type: "business_concept",
          source_id: id,
          target_id: id + 1,
          tag: tag
        )
      end)

    assert %{nodes: nodes, edges: edges} = Resources.graph(claims, 5, "business_concept")
    assert Enum.all?(1..11, fn id -> Enum.find(nodes, &(&1.id == "business_concept:#{id}")) end)

    assert Enum.all?(relations, fn %{
                                     source_id: source_id,
                                     source_type: source_type,
                                     target_id: target_id,
                                     target_type: target_type,
                                     tag: tag
                                   } ->
             Enum.find(
               edges,
               &(&1.source_id == "#{source_type}:#{source_id}" and
                   &1.target_id == "#{target_type}:#{target_id}" and
                   &1.tag == tag)
             )
           end)
  end

  test "graph/3 gets empty edges and nodes when we query an non existing node" do
    tag = insert(:tag)
    claims = %Claims{user_id: 1, role: "admin"}

    Enum.map(1..10, fn id ->
      insert(:relation,
        source_type: "business_concept",
        target_type: "business_concept",
        source_id: id,
        target_id: id + 1,
        tag: tag
      )
    end)

    assert %{nodes: [], edges: []} = Resources.graph(claims, 12, "business_concept")
  end

  describe "deprecate/1" do
    setup [:put_template, :put_concept]

    test "logically deletes relations" do
      IndexWorkerMock.clear()

      %{id: id1, target_id: tid1} = insert(:relation, target_type: "data_structure")
      %{id: id2, target_id: tid2} = insert(:relation, target_type: "data_structure")

      %{target_id: tid3} =
        insert(:relation, target_type: "data_structure", deleted_at: DateTime.utc_now())

      assert {:ok, %{deprecated: deprecated}} =
               Resources.deprecate("data_structure", [tid1, tid2, tid3])

      assert {2, [%{id: ^id1}, %{id: ^id2}]} = deprecated

      assert [{:delete, :relations, [^id1, ^id2]}] = IndexWorkerMock.calls()
    end

    test "publishes audit events", %{concept: %{id: concept_id, domain_id: domain_id}} do
      domain_ids = [domain_id]

      %{target_id: tid1} =
        insert(:relation,
          source_id: concept_id,
          source_type: "business_concept",
          target_type: "data_structure"
        )

      %{target_id: tid2} = insert(:relation, target_type: "data_structure")

      %{target_id: tid3} =
        insert(:relation, target_type: "data_structure", deleted_at: DateTime.utc_now())

      assert {:ok, %{audit: audit}} = Resources.deprecate("data_structure", [tid1, tid2, tid3])
      assert length(audit) == 2
      [event_id | _] = audit

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{"domain_ids" => ^domain_ids} = Jason.decode!(payload)
    end
  end

  describe "activate/1" do
    test "logically deletes relations" do
      %{target_id: tid1} = insert(:relation, target_type: "data_structure")
      %{target_id: tid2} = insert(:relation, target_type: "data_structure")

      %{id: id3, target_id: tid3} =
        insert(:relation, target_type: "data_structure", deleted_at: DateTime.utc_now())

      assert {:ok, %{activated: activated}} =
               Resources.activate("data_structure", [tid1, tid2, tid3])

      assert {1, [%{id: ^id3}]} = activated
    end
  end

  describe "migrate_impl_ids_to_impl_ref/1" do
    test "update relations for implementation_id to implementation_ref" do
      %{id: relation_id_1, source_id: source_id_relation_1_from} =
        insert(:relation,
          source_type: "implementation",
          target_type: "bussiness_concept",
          source_id: 123
        )

      %{id: relation_id_2, source_id: source_id_relation_2_from} =
        insert(:relation,
          source_type: "implementation",
          target_type: "bussiness_concept",
          source_id: 222
        )

      relation_3 =
        insert(:relation,
          source_type: "implementation",
          target_type: "bussiness_concept",
          source_id: 333
        )

      source_id_relation_1_to = 246
      source_id_relation_2_to = 222

      assert [^relation_id_1, ^relation_id_2] =
               Resources.migrate_impl_id_to_impl_ref([
                 source_id_relation_1_from,
                 source_id_relation_1_to,
                 source_id_relation_2_from,
                 source_id_relation_2_to
               ])

      [new_relation_1, new_relation_2, new_relation_3] = Resources.list_relations()

      assert %{
               id: ^relation_id_1,
               source_type: "implementation_ref",
               source_id: ^source_id_relation_1_to
             } = new_relation_1

      assert %{
               id: ^relation_id_2,
               source_type: "implementation_ref",
               source_id: ^source_id_relation_2_to
             } = new_relation_2

      assert ^relation_3 = new_relation_3
    end
  end

  describe "bulk_create_relations/1" do
    test "Create relation with valid data" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure,
        tag: %{id: tag_id}
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          tag: [value: %{"type" => "foo", "target_type" => "data_field"}],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [first] = created, "updated" => [], "errors" => []}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert length(created) == length(bulk_insert_params)

      assert %{source_id: ^concept_id, target_id: ^data_structure_id, tag_id: ^tag_id} =
               Resources.get_relation!(first)
    end

    test "user can not create relation if business concepts is confidential" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "user"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc", confidential: true],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :manage_business_concept_links,
        :link_data_structure
      ])

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "without_permissions"

      assert error["body"]["context"]["error"] == "domain_external_id_1"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.without_permissions"
    end

    test "Create relation with valid data without tag" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: [params],
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      bulk_insert_params = [Map.put(params, "tag", "")]

      assert {:ok, %{"created" => [first] = created, "updated" => [], "errors" => []}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert length(created) == length(bulk_insert_params)

      assert %{source_id: ^concept_id, target_id: ^data_structure_id, tag_id: tag_id} =
               Resources.get_relation!(first)

      assert is_nil(tag_id)
    end

    test "user non-admin can not create relations without permissions" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "user"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc"],
          tag: [value: %{"type" => "foo", "target_type" => "data_field"}],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "without_permissions"

      assert error["body"]["context"]["error"] == "domain_external_id_1"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.without_permissions"
    end

    test "user can not create relations without structure permissions" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "user"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :manage_confidential_business_concepts,
        :manage_business_concept_links
      ])

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "without_permissions"

      assert error["body"]["context"]["error"] == "data_structure"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.without_permissions"
    end

    test "user can create relations with permissions" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "user"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :manage_confidential_business_concepts,
        :manage_business_concept_links,
        :link_data_structure,
        :view_data_structure
      ])

      assert {:ok, %{"created" => [first] = created, "updated" => [], "errors" => []}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert length(created) == length(bulk_insert_params)

      assert %{source_id: ^concept_id, target_id: ^data_structure_id, tag_id: tag_id} =
               Resources.get_relation!(first)

      assert is_nil(tag_id)
    end

    test "user can create relations with permissions on shared domain" do
      %{id: spd_id} =
        CacheHelpers.put_domain(external_id: "shared_parent_domain_1")

      %{id: spd_child_id} =
        CacheHelpers.put_domain(external_id: "shared_child_domain_1", parent_id: spd_id)

      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "user"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc", shared_to: [%{id: spd_child_id}]],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      CacheHelpers.put_session_permissions(claims, %{
        "link_data_structure" => [domain_id],
        "view_data_structure" => [domain_id],
        "manage_business_concept_links" => [spd_id]
      })

      assert {:ok, %{"created" => [first] = created, "updated" => [], "errors" => []}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert length(created) == length(bulk_insert_params)

      assert %{source_id: ^concept_id, target_id: ^data_structure_id, tag_id: tag_id} =
               Resources.get_relation!(first)

      assert is_nil(tag_id)
    end

    test "user can create relations with permissions to manage confidential concepts on shared domain" do
      %{id: spd_id} =
        CacheHelpers.put_domain(external_id: "shared_parent_domain_1")

      %{id: spd_child_id} =
        CacheHelpers.put_domain(external_id: "shared_child_domain_1", parent_id: spd_id)

      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "user"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc", shared_to: [%{id: spd_child_id}], confidential: true],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      CacheHelpers.put_session_permissions(claims, %{
        "link_data_structure" => [domain_id],
        "view_data_structure" => [domain_id],
        "manage_confidential_business_concept" => [spd_id],
        "manage_business_concept_links" => [spd_id]
      })

      assert {:ok, %{"created" => [first] = created, "updated" => [], "errors" => []}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert length(created) == length(bulk_insert_params)

      assert %{source_id: ^concept_id, target_id: ^data_structure_id, tag_id: tag_id} =
               Resources.get_relation!(first)

      assert is_nil(tag_id)
    end

    test "user can't create relations without permissions to manage confidential concepts on shared domain" do
      %{id: spd_id} =
        CacheHelpers.put_domain(external_id: "shared_parent_domain_1")

      %{id: spd_child_id} =
        CacheHelpers.put_domain(external_id: "shared_child_domain_1", parent_id: spd_id)

      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "user"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc", shared_to: [%{id: spd_child_id}], confidential: true],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      CacheHelpers.put_session_permissions(claims, %{
        "link_data_structure" => [domain_id],
        "view_data_structure" => [domain_id],
        "manage_business_concept_links" => [spd_id]
      })

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "without_permissions"

      assert error["body"]["context"]["error"] == "domain_external_id_1"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.without_permissions"
    end

    test "can not create relations if already exists with tag" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure,
        tag: tag
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          tag: [value: %{"type" => "foo", "target_type" => "data_field"}],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      insert(:relation,
        source_type: "business_concept",
        source_id: concept_id,
        target_type: "data_structure",
        target_id: data_structure_id,
        tag: tag
      )

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "already_exists"

      assert error["body"]["context"]["error"] == ""

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.already_exists"
    end

    test "can not create relations if already exists without tag" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      insert(:relation,
        source_type: "business_concept",
        source_id: concept_id,
        target_type: "data_structure",
        target_id: data_structure_id,
        tag: nil
      )

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "already_exists"

      assert error["body"]["context"]["error"] == ""

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.already_exists"
    end

    test "can not create relation without params" do
      claims = build(:claims, role: "admin")

      bulk_insert_params = [
        %{
          "row_number" => 1,
          "source_param" => "",
          "target_type" => "",
          "target_param" => "",
          "domain_external_id" => ""
        }
      ]

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "missing_params"

      assert error["body"]["context"]["error"] ==
               "source_param, source_type, target_param, target_type, domain_external_id"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.missing_params"
    end

    test "can not create relation without source_type" do
      claims = build(:claims, role: "admin")

      domain_external_id = "domain_external_id_1"

      bulk_insert_params = [
        %{
          "row_number" => 1,
          "source_param" => "foo_bc",
          "source_type" => "",
          "target_type" => "data_structure",
          "target_param" => "bar_ds_external_id",
          "domain_external_id" => domain_external_id
        }
      ]

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "missing_params"

      assert error["body"]["context"]["error"] == "source_type"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.missing_params"
    end

    test "can not create relation without source_param" do
      claims = build(:claims, role: "admin")

      domain_external_id = "domain_external_id_1"

      bulk_insert_params = [
        %{
          "row_number" => 1,
          "source_param" => "",
          "source_type" => "business_concept",
          "target_type" => "data_structure",
          "target_param" => "bar_ds_external_id",
          "domain_external_id" => domain_external_id
        }
      ]

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "missing_params"

      assert error["body"]["context"]["error"] == "source_param"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.missing_params"
    end

    test "can not create relation without target_type" do
      claims = build(:claims, role: "admin")

      domain_external_id = "domain_external_id_1"

      bulk_insert_params = [
        %{
          "row_number" => 1,
          "source_type" => "business_concept",
          "source_param" => "foo_bc",
          "target_type" => "",
          "target_param" => "bar_ds_external_id",
          "domain_external_id" => domain_external_id
        }
      ]

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "missing_params"

      assert error["body"]["context"]["error"] == "target_type"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.missing_params"
    end

    test "can not create relation without target_param" do
      claims = build(:claims, role: "admin")

      domain_external_id = "domain_external_id_1"

      bulk_insert_params = [
        %{
          "row_number" => 1,
          "source_type" => "business_concept",
          "source_param" => "foo_bc",
          "target_type" => "data_structure",
          "target_param" => "",
          "domain_external_id" => domain_external_id
        }
      ]

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "missing_params"

      assert error["body"]["context"]["error"] == "target_param"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.missing_params"
    end

    test "can not create relation without domain_external_id" do
      claims = build(:claims, role: "admin")

      bulk_insert_params = [
        %{
          "row_number" => 1,
          "source_type" => "business_concept",
          "source_param" => "foo_bc",
          "target_type" => "data_structure",
          "target_param" => "bar_ds_external_id",
          "domain_external_id" => ""
        }
      ]

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "missing_params"

      assert error["body"]["context"]["error"] == "domain_external_id"

      assert error["body"]["message"] == "bulk_creation_link.upload.failed.missing_params"
    end

    test "can not create relation if domain not exists" do
      claims = build(:claims, role: "admin")

      domain = CacheHelpers.put_domain(external_id: "domain_external_id_1")

      data_structure =
        build(:data_structure,
          external_id: "bar_ds_external_id",
          domain: domain
        )

      bulk_insert_params = [
        %{
          "row_number" => 1,
          "source_type" => "business_concept",
          "source_param" => "foo_bc",
          "target_type" => "data_structure",
          "target_param" => "bar_ds_external_id",
          "domain_external_id" => "foo"
        }
      ]

      data_structure_mock("bar_ds_external_id", {:ok, data_structure})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "not_available"

      assert error["body"]["context"]["error"] == "business_concept"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.not_exists"
    end

    test "can not create relation if concept is deprecated" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [
            name: "foo_bc",
            versions: [%{status: "deprecated", version: 2}, %{status: "published", version: 1}]
          ],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "not_available"

      assert error["body"]["context"]["error"] == "business_concept"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.deprecated"
    end

    test "can not create relation if concept is deprecated and structure not exists" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id}
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [
            name: "foo_bc",
            versions: [%{status: "deprecated", version: 2}, %{status: "published", version: 1}]
          ],
          structure: [external_id: "bar_ds_external_id"]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, nil})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "not_available"

      assert error["body"]["context"]["error"] == "business_concept && data_structure"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.source.deprecated.target.not_exists"
    end

    test "can not create relation if concept is deprecated and structure is deleted" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [
            name: "foo_bc",
            versions: [%{status: "deprecated", version: 2}, %{status: "published", version: 1}]
          ],
          structure: [
            external_id: "bar_ds_external_id",
            latest_version: %{deleted_at: DateTime.utc_now()}
          ]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "not_available"

      assert error["body"]["context"]["error"] == "business_concept && data_structure"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.source.deprecated.target.deleted"
    end

    test "can not create relation if concept not exists" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: params,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          structure: [
            external_id: "bar_ds_external_id",
            latest_version: %{deleted_at: nil}
          ]
        )

      bulk_insert_params =
        Map.put(hd(params), "source_param", "foo_bc")

      business_concept_mock("foo_bc", domain_id, {:ok, nil})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations([bulk_insert_params], claims)

      assert error["error_type"] == "not_available"
      assert error["body"]["context"]["error"] == "business_concept"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.not_exists"
    end

    test "can not create relation if concept not exists and structure is deleted" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: params,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          structure: [
            external_id: "bar_ds_external_id",
            latest_version: %{deleted_at: DateTime.utc_now()}
          ]
        )

      bulk_insert_params =
        Map.put(hd(params), "source_param", "foo_bc")

      business_concept_mock("foo_bc", domain_id, {:ok, nil})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations([bulk_insert_params], claims)

      assert error["error_type"] == "not_available"
      assert error["body"]["context"]["error"] == "business_concept && data_structure"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.source.not_exists.target.deleted"
    end

    test "can not create relation if concept not exists and structure not exists" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: params,
        data_structure: %{external_id: data_structure_external_id}
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          structure: [external_id: "bar_ds_external_id"]
        )

      bulk_insert_params =
        Map.put(hd(params), "source_param", "foo_bc")

      business_concept_mock("foo_bc", domain_id, {:ok, nil})
      data_structure_mock(data_structure_external_id, {:ok, nil})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations([bulk_insert_params], claims)

      assert error["error_type"] == "not_available"
      assert error["body"]["context"]["error"] == "business_concept && data_structure"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.source.not_exists.target.not_exists"
    end

    test "can not create relation if data structure not exists" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: params,
        concept: %{name: concept_name} = concept
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [
            name: "foo_bc",
            versions: [%{status: "published", version: 1}]
          ]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock("bar_ds_external_id", {:ok, nil})

      bulk_insert_params =
        Map.put(hd(params), "target_param", "bar_ds_external_id")

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations([bulk_insert_params], claims)

      assert error["error_type"] == "not_available"
      assert error["body"]["context"]["error"] == "data_structure"

      assert error["body"]["message"] ==
               "bulk_creation_link.upload.failed.not_available.not_exists"
    end

    test "can not create relation if data structure is deleted" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: bulk_insert_params,
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [
            name: "foo_bc",
            versions: [%{status: "published", version: 1}]
          ],
          structure: [
            external_id: "bar_ds_external_id",
            latest_version: %{deleted_at: DateTime.utc_now()}
          ]
        )

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "not_available"
      assert error["body"]["context"]["error"] == "data_structure"
      assert error["body"]["message"] == "bulk_creation_link.upload.failed.not_available.deleted"
    end

    test "Validate duplicates params with tag" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: [params],
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          tag: [value: %{"type" => "foo", "target_type" => "data_structure"}],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      bulk_insert_params = [params, %{params | "row_number" => 2}]

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [_created], "updated" => [], "errors" => [error]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "duplicate_in_file"
      assert error["body"]["context"]["error"] == ""
      assert error["body"]["context"]["row"] == 2
      assert error["body"]["message"] == "bulk_creation_link.upload.failed.duplicate_in_file"
    end

    test "Validate duplicates params without tag" do
      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: [params],
        concept: %{name: concept_name} = concept,
        data_structure: %{external_id: data_structure_external_id} = data_structure
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc"],
          structure: [external_id: "bar_ds_external_id"]
        )

      bulk_insert_params =
        [params, %{params | "row_number" => 2}, %{params | "row_number" => 3}]

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      assert {:ok, %{"created" => [_created], "updated" => [], "errors" => [error, error2]}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert error["error_type"] == "duplicate_in_file"
      assert error["body"]["context"]["error"] == ""
      assert error["body"]["context"]["row"] == 2
      assert error["body"]["message"] == "bulk_creation_link.upload.failed.duplicate_in_file"
      assert error2["error_type"] == "duplicate_in_file"
      assert error2["body"]["context"]["error"] == ""
      assert error2["body"]["context"]["row"] == 3
      assert error2["body"]["message"] == "bulk_creation_link.upload.failed.duplicate_in_file"
    end

    test "publish audit events" do
      put_template(nil)

      %{
        claims: claims,
        domain: %{id: domain_id},
        bulk_insert_params: [params],
        concept: %{id: concept_id, name: concept_name} = concept,
        data_structure:
          %{id: data_structure_id, external_id: data_structure_external_id} = data_structure,
        tag: %{id: tag_id}
      } =
        create_mock_data(
          claims: [role: "admin"],
          domain: [external_id: "domain_external_id_1"],
          concept: [name: "foo_bc", type: "foo", content: %{"foo" => "bar"}],
          structure: [external_id: "bar_ds_external_id"],
          tag: [value: %{"type" => "foo", "target_type" => "data_field"}]
        )

      CacheHelpers.put_concept(concept)

      business_concept_mock(concept_name, domain_id, {:ok, concept})
      data_structure_mock(data_structure_external_id, {:ok, data_structure})

      bulk_insert_params = [Map.put(params, "tag", "")]

      assert {:ok, %{"created" => [first], "updated" => [], "errors" => []}} =
               Resources.bulk_create_relations(bulk_insert_params, claims)

      assert %{source_id: ^concept_id, target_id: ^data_structure_id} =
               Resources.get_relation!(first)

      assert {:ok, [%{id: _, resource_id: resource_id, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert resource_id == "#{concept_id}"

      assert %{
               "tag_id" => ^tag_id,
               "subscribable_fields" => %{"foo" => "bar"},
               "domain_ids" => [^domain_id]
             } =
               Jason.decode!(payload)
    end
  end

  def create_mock_data(opts \\ []) do
    opts_map = Enum.into(opts, %{})

    %{
      opts: opts_map
    }
    |> maybe_create_claims()
    |> maybe_create_domain()
    |> maybe_create_tag()
    |> maybe_create_concept()
    |> maybe_create_data_structure()
    |> build_bulk_insert_params()
  end

  defp maybe_create_claims(%{opts: %{claims: claims_params}} = acc) do
    claims = build(:claims, claims_params)
    Map.put(acc, :claims, claims)
  end

  defp maybe_create_claims(acc), do: acc

  defp maybe_create_domain(%{opts: %{domain: domain_params}} = acc) do
    domain = CacheHelpers.put_domain(domain_params)
    Map.put(acc, :domain, domain)
  end

  defp maybe_create_domain(acc), do: acc

  defp maybe_create_tag(%{opts: %{tag: tag_params}} = acc) do
    tag = insert(:tag, tag_params)

    Map.put(acc, :tag, tag)
  end

  defp maybe_create_tag(acc), do: acc

  defp maybe_create_concept(
         %{opts: %{concept: concept_params}, domain: %{id: domain_id} = domain} = acc
       ) do
    params = concept_params ++ [domain_id: domain_id, domain: domain]

    concept = CacheHelpers.put_concept(params)

    Map.put(acc, :concept, concept)
  end

  defp maybe_create_concept(acc), do: acc

  defp maybe_create_data_structure(
         %{opts: %{structure: structure_params}, domain: %{id: domain_id} = domain} = acc
       ) do
    params = structure_params ++ [domain_id: domain_id, domain: domain, domain_ids: [domain_id]]

    ds = build(:data_structure, params)

    Map.put(acc, :data_structure, ds)
  end

  defp maybe_create_data_structure(acc), do: acc

  defp build_bulk_insert_params(
         %{
           domain: %{external_id: domain_external_id}
         } = acc
       ) do
    tag_type =
      acc
      |> Map.get(:tag)
      |> then(&(&1 && Map.get(&1.value, "type")))

    concept_name =
      acc
      |> Map.get(:concept, %{})
      |> Map.get(:name, "")

    ds_external_id =
      acc
      |> Map.get(:data_structure, %{})
      |> Map.get(:external_id, "")

    tag_target_type = if is_nil(tag_type), do: nil, else: "data_field"

    bulk_insert_params =
      %{
        "row_number" => 1,
        "source_type" => "business_concept",
        "target_type" => "data_structure",
        "domain_external_id" => domain_external_id
      }
      |> maybe_put("source_param", concept_name)
      |> maybe_put("target_param", ds_external_id)
      |> maybe_put("link_type", tag_type)
      |> Map.put("tag_target_type", tag_target_type)

    Map.put(acc, :bulk_insert_params, [bulk_insert_params])
  end

  defp build_bulk_insert_params(acc), do: acc

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp business_concept_mock(name, domain_id, result) do
    TdBgMock.get_concept_by_name_in_domain(&Mox.expect/4, name, domain_id, result)
  end

  defp data_structure_mock(external_id, result) do
    TdDdMock.get_data_structure_by_external_id(
      &Mox.expect/4,
      external_id,
      :latest_version,
      result
    )
  end

  defp put_template(_) do
    template =
      CacheHelpers.put_template(
        name: "foo",
        scope: "test",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                name: "foo",
                type: "string",
                cardinality: "?",
                values: %{"fixed" => ["bar"]},
                subscribable: true
              },
              %{
                name: "xyz",
                type: "string",
                cardinality: "?",
                values: %{"fixed" => ["foo"]}
              }
            ]
          }
        ]
      )

    [template: template]
  end

  defp put_concept(_) do
    %{id: domain_id} = CacheHelpers.put_domain()

    concept =
      CacheHelpers.put_concept(
        domain_id: domain_id,
        name: "concept_name",
        type: "foo",
        content: %{"foo" => "bar"}
      )

    [concept: concept]
  end
end
