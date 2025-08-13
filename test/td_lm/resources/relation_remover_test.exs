defmodule TdLm.RelationRemoverTest do
  use TdLm.DataCase

  alias TdCache.ImplementationCache
  alias TdCache.Redix
  alias TdLm.Cache.LinkLoader
  alias TdLm.Cache.LinkRemover
  alias TdLm.RelationRemover
  alias TdLm.Resources.Relation

  @stream TdCache.Audit.stream()

  setup do
    Redix.del!(@stream)
    start_supervised(LinkLoader)
    # Use this inside setup, not setup_all, so that self() is the same PID used
    # in the test
    {:ok, _pid} = LinkRemover.start_link(parent: self())

    implementation_id = 1

    implementation = %{
      id: implementation_id,
      implementation_ref: implementation_id,
      updated_at: ~U[2007-08-31 00:00:00Z],
      deleted_at: nil
    }

    on_exit(fn -> Redix.del!(@stream) end)

    on_exit(fn ->
      ImplementationCache.delete(implementation_id)
      Redix.command(["SREM", "implementation:deleted_ids", implementation_id])
    end)

    [implementation: implementation]
  end

  test "remove_stale_implementation_relations", %{
    implementation: %{id: implementation_id} = implementation
  } do
    # Existing implementation is in ImplementationCache
    ImplementationCache.put(implementation)

    # Relation pointing from an existing implementation
    {:ok, %{id: id_good_relation} = good_relation} =
      %TdLm.Resources.Relation{
        source_type: "implementation_ref",
        source_id: implementation_id,
        target_type: "business_concept",
        target_id: 1
      }
      |> Repo.insert()

    # Stale relation pointing from a non-existent implementation (previously
    # deleted, not present in ImplementationCache)
    {:ok, %{id: id_stale_relation} = stale_relation} =
      %Relation{
        source_type: "implementation_ref",
        source_id: 2,
        target_type: "business_concept",
        target_id: 2,
        tag_id: nil
      }
      |> Repo.insert()

    TdCache.LinkCache.put(good_relation)
    TdCache.LinkCache.put(stale_relation)

    RelationRemover.remove_stale_implementation_relations()

    id_string_stale_relation = "#{id_stale_relation}"

    assert {:consumed,
            [
              %{
                event: "delete_link",
                link_id: ^id_string_stale_relation,
                stream: "link:commands"
              }
            ]} = consume_events()

    # Stale relation has been deleted, only good_relation remains
    assert [
             %{id: ^id_good_relation}
           ] = TdLm.Repo.all(Relation)
  end

  defp consume_events do
    receive do
      m -> m
    after
      5_000 -> :timeout
    end
  end
end
