defmodule TdLm.ResourcesTest do
  use TdLm.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdLm.Auth.Claims
  alias TdLm.Resources
  alias TdLm.Resources.Relation

  @stream TdCache.Audit.stream()

  setup_all do
    Redix.del!(@stream)
    [claims: build(:claims)]
  end

  setup do
    start_supervised!(TdLm.Cache.LinkLoader)
    on_exit(fn -> Redix.del!(@stream) end)
    :ok
  end

  describe "create_relation/2" do
    setup [:put_template, :put_concept]

    test "creates a relation without tags", %{claims: claims} do
      %{
        "source_id" => source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type
      } = params = string_params_for(:relation)

      assert {:ok, %{relation: relation}} = Resources.create_relation(params, claims)

      assert %{
               source_id: ^source_id,
               source_type: ^source_type,
               target_id: ^target_id,
               target_type: ^target_type,
               context: context
             } = relation

      assert context == %{}
    end

    test "creates a relation with the specified tags", %{claims: claims} do
      tag_ids =
        1..3
        |> Enum.map(fn _ -> insert(:tag) end)
        |> Enum.map(& &1.id)

      params = string_params_for(:relation) |> Map.put("tag_ids", tag_ids)
      assert {:ok, %{relation: relation}} = Resources.create_relation(params, claims)
      assert %{tags: tags} = relation
      assert length(tags) == 3
      assert Enum.all?(tags, &(&1.id in tag_ids))
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

    test "returns error and changeset if validations fail", %{claims: claims} do
      params = %{"source_id" => nil}

      assert {:error, :relation, %Ecto.Changeset{}, _} = Resources.create_relation(params, claims)
    end
  end

  describe "delete_relation/2" do
    setup [:put_template, :put_concept]

    test "delete_relation/2 deletes", %{claims: claims} do
      relation = insert(:relation)
      assert {:ok, %{relation: relation}} = Resources.delete_relation(relation, claims)
      assert %{__meta__: %{state: :deleted}} = relation
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

    relation_1 = insert(:relation, tags: [tag_1], source_type: "new type")
    relation_2 = insert(:relation, tags: [tag_2])
    relation_3 = insert(:relation, tags: [tag_3])

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

    # min_id
    {%{id: min_id}, %{id: max_id}} = Enum.min_max_by(relations, & &1.id)
    assert_lists_equal(relations, Resources.list_relations(%{"min_id" => min_id}))
    assert [%{id: ^max_id}] = Resources.list_relations(%{"min_id" => max_id})

    # since
    {%{updated_at: min_ts}, %{updated_at: max_ts}} =
      Enum.min_max_by(relations, & &1.updated_at, DateTime)

    assert_lists_equal(relations, Resources.list_relations(%{"since" => min_ts}))
    assert [%{updated_at: ^max_ts}] = Resources.list_relations(%{"since" => max_ts})

    # limit
    assert_lists_equal(Enum.take(relations, 5), Resources.list_relations(%{"limit" => 5}))
  end

  test "get_relation!/1 returns the relation with given id" do
    relation = insert(:relation)
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
      params = %{"value" => nil}
      assert {:error, :tag, %Ecto.Changeset{}, _} = Resources.create_tag(params, claims)
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

  describe "delete_tag/2" do
    test "deletes the tag and updates it's relations", %{claims: claims} do
      relations = Enum.map(1..5, fn _ -> insert(:relation) end)
      tag = insert(:tag, relations: relations)

      assert {:ok, %{tag: tag, relations: rels}} = Resources.delete_tag(tag, claims)
      assert %{__meta__: %{state: :deleted}} = tag
      assert {5, updated_ids} = rels
      assert Enum.all?(relations, &(&1.id in updated_ids))
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

    insert(:relation, tags: [tag_1])
    insert(:relation, tags: [tag_2])

    result_tags = Resources.list_tags(%{"value" => %{"type" => "First type"}})

    assert [%{id: ^id1}] = result_tags
  end

  test "get_tag!/1 returns the tag with given id" do
    tag = insert(:tag, relations: [])
    assert Resources.get_tag!(tag.id) == tag
  end

  test "graph/3 gets edges and nodes" do
    tags = Enum.map(1..5, fn _ -> insert(:tag) end)
    claims = %Claims{user_id: 1, role: "admin"}

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

    assert %{nodes: nodes, edges: edges} = Resources.graph(claims, 5, "business_concept")
    assert Enum.all?(1..11, fn id -> Enum.find(nodes, &(&1.id == "business_concept:#{id}")) end)

    assert Enum.all?(relations, fn %{
                                     source_id: source_id,
                                     source_type: source_type,
                                     target_id: target_id,
                                     target_type: target_type
                                   } ->
             Enum.find(
               edges,
               &(&1.source_id == "#{source_type}:#{source_id}" and
                   &1.target_id == "#{target_type}:#{target_id}")
             )
           end)
  end

  test "graph/3 gets empty edges and nodes when we query an non existing node" do
    tags = Enum.map(1..5, fn _ -> insert(:tag) end)
    claims = %Claims{user_id: 1, role: "admin"}

    Enum.map(1..10, fn id ->
      insert(:relation,
        source_type: "business_concept",
        target_type: "business_concept",
        source_id: id,
        target_id: id + 1,
        tags: tags
      )
    end)

    assert %{nodes: [], edges: []} = Resources.graph(claims, 12, "business_concept")
  end

  describe "deprecate/1" do
    setup [:put_template, :put_concept]

    test "logically deletes relations" do
      %{id: id1, target_id: tid1} = insert(:relation, target_type: "data_structure")
      %{id: id2, target_id: tid2} = insert(:relation, target_type: "data_structure")

      %{target_id: tid3} =
        insert(:relation, target_type: "data_structure", deleted_at: DateTime.utc_now())

      assert {:ok, %{deprecated: deprecated}} =
               Resources.deprecate("data_structure", [tid1, tid2, tid3])

      assert {2, [%{id: ^id1}, %{id: ^id2}]} = deprecated
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
      CacheHelpers.put_concept(domain_id: domain_id, type: "foo", content: %{"foo" => "bar"})

    [concept: concept]
  end
end
