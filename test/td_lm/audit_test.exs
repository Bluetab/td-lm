defmodule TdLm.AuditTest do
  use TdLm.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdLm.Audit

  @stream TdCache.Audit.stream()

  setup do
    Redix.del!(@stream)

    concept = put_concept()
    user = build(:user)

    %{concept: concept, user: user}
  end

  describe "relation_created/4" do
    test "publishes audit event with event_via when set in process dictionary", %{
      concept: %{id: concept_id},
      user: %{id: user_id}
    } do
      %{id: relation_id, source_id: source_id, target_id: target_id} =
        relation =
        build(:relation,
          source_id: concept_id,
          source_type: "business_concept",
          target_type: "business_concept",
          tags: []
        )

      changes = %{
        source_id: source_id,
        source_type: "business_concept",
        target_id: target_id,
        target_type: "business_concept"
      }

      Process.put(:event_via, "single_update")

      assert {:ok, _event_id} =
               Audit.relation_created(
                 nil,
                 %{relation_with_optional_tag: relation},
                 %{changes: changes},
                 user_id
               )

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_created"

      assert %{"event_via" => "single_update", "id" => ^relation_id} = Jason.decode!(payload)
    end

    test "publishes audit event with nil event_via when not set in process dictionary", %{
      concept: %{id: concept_id},
      user: %{id: user_id}
    } do
      %{id: relation_id, source_id: source_id, target_id: target_id} =
        relation =
        build(:relation,
          source_id: concept_id,
          source_type: "business_concept",
          target_type: "business_concept",
          tags: []
        )

      changes = %{
        source_id: source_id,
        source_type: "business_concept",
        target_id: target_id,
        target_type: "business_concept"
      }

      Process.delete(:event_via)

      assert {:ok, _event_id} =
               Audit.relation_created(
                 nil,
                 %{relation_with_optional_tag: relation},
                 %{changes: changes},
                 user_id
               )

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_created"

      assert %{"event_via" => nil, "id" => ^relation_id} = Jason.decode!(payload)
    end

    test "publishes audit event for quality control", %{
      user: %{id: user_id}
    } do
      source_id = System.unique_integer([:positive])
      domain_id = System.unique_integer([:positive])
      source_type = "quality_control"
      target_type = "data_structure"

      %{target_id: target_id} =
        relation =
        build(:relation,
          source_id: source_id,
          source_type: source_type,
          target_type: target_type,
          tags: []
        )

      changes = %{
        source_id: source_id,
        source_type: source_type,
        target_id: target_id,
        target_type: target_type
      }

      Mox.expect(MockClusterHandler, :call, 2, fn :qx, TdQx.QualityControls, :get, [^source_id] ->
        {:ok, %{domain_ids: [domain_id]}}
      end)

      Process.put(:event_via, "single_update")

      assert {:ok, _event_id} =
               Audit.relation_created(
                 nil,
                 %{relation_with_optional_tag: relation},
                 %{changes: changes},
                 user_id
               )

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_created"

      assert %{
               "event_via" => "single_update",
               "source_id" => ^source_id,
               "domain_ids" => [^domain_id]
             } = Jason.decode!(payload)
    end
  end

  describe "relation_deleted/3" do
    test "publishes audit event with event_via when set in process dictionary", %{
      concept: %{id: concept_id},
      user: %{id: user_id}
    } do
      %{id: relation_id, target_id: target_id} =
        relation =
        build(:relation,
          source_id: concept_id,
          source_type: "business_concept",
          target_type: "business_concept",
          status: nil
        )

      Process.put(:event_via, "single_update")

      assert {:ok, _event_id} =
               Audit.relation_deleted(
                 nil,
                 %{relation: relation},
                 user_id
               )

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_deleted"

      assert %{
               "event_via" => "single_update",
               "id" => ^relation_id,
               "target_id" => ^target_id
             } = Jason.decode!(payload)
    end

    test "publishes audit event with nil event_via when not set in process dictionary", %{
      concept: %{id: concept_id},
      user: %{id: user_id}
    } do
      %{id: relation_id, target_id: target_id} =
        relation =
        build(:relation,
          source_id: concept_id,
          source_type: "business_concept",
          target_type: "business_concept",
          status: nil
        )

      Process.delete(:event_via)

      assert {:ok, _event_id} =
               Audit.relation_deleted(
                 nil,
                 %{relation: relation},
                 user_id
               )

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_deleted"

      assert %{
               "event_via" => nil,
               "id" => ^relation_id,
               "target_id" => ^target_id
             } = Jason.decode!(payload)
    end

    test "publishes audit event for quality control", %{
      user: %{id: user_id}
    } do
      source_id = System.unique_integer([:positive])
      domain_id = System.unique_integer([:positive])
      source_type = "quality_control"
      target_type = "data_structure"

      relation =
        build(:relation,
          source_id: source_id,
          source_type: source_type,
          target_type: target_type,
          tags: []
        )

      Mox.expect(MockClusterHandler, :call, 2, fn :qx, TdQx.QualityControls, :get, [^source_id] ->
        {:ok, %{domain_ids: [domain_id]}}
      end)

      Process.put(:event_via, "single_update")

      assert {:ok, _event_id} =
               Audit.relation_deleted(
                 nil,
                 %{relation: relation},
                 user_id
               )

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_deleted"

      assert %{
               "event_via" => "single_update",
               "domain_ids" => [^domain_id],
               "target_type" => ^target_type
             } = Jason.decode!(payload)
    end
  end

  describe "bulk_relation_creation/3" do
    test "publishes audit events with event_via when set in process dictionary", %{
      concept: %{id: concept_id},
      user: %{id: user_id}
    } do
      %{id: relation_id} =
        relation =
        build(:relation,
          source_id: concept_id,
          source_type: "business_concept",
          target_type: "business_concept",
          tag_id: nil
        )

      data = [{:ok, relation}]

      Process.put(:event_via, "bulk_upload")

      assert {:ok, [_event_id]} = Audit.bulk_relation_creation(nil, data, user_id)

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_created"

      assert %{"event_via" => "bulk_upload", "id" => ^relation_id} = Jason.decode!(payload)
    end

    test "publishes audit events with nil event_via when not set in process dictionary", %{
      concept: %{id: concept_id},
      user: %{id: user_id}
    } do
      %{id: relation_id} =
        relation =
        build(:relation,
          source_id: concept_id,
          source_type: "business_concept",
          target_type: "business_concept",
          tag_id: nil
        )

      data = [{:ok, relation}]

      Process.delete(:event_via)

      assert {:ok, [_event_id]} = Audit.bulk_relation_creation(nil, data, user_id)

      assert {:ok, [%{event: event, payload: payload}]} =
               Stream.read(:redix, @stream, transform: true)

      assert event == "relation_created"

      assert %{"event_via" => nil, "id" => ^relation_id} = Jason.decode!(payload)
    end
  end

  defp put_concept do
    %{id: domain_id} = CacheHelpers.put_domain()

    CacheHelpers.put_concept(
      domain_id: domain_id,
      name: "concept_name",
      type: "foo",
      content: %{"foo" => "bar"}
    )
  end
end
