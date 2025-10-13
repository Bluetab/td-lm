defmodule TdCluster.ClusterTdLmTest do
  use TdLm.DataCase
  alias TdCache.Redix
  alias TdCluster.Cluster, as: Cluster
  alias TdLm.Resources

  import Mox

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

  setup :verify_on_exit!

  describe "test Cluster.TdLm functions" do
    test "clone_relations copy relations to new implementation", %{claims: claims} do
      Application.put_env(:td_cluster, TdCluster.ClusterHandler, TdCluster.ClusterHandlerImpl)

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

      assert length(
               Resources.list_relations(%{
                 "target_type" => target_type,
                 "source_id" => original_id
               })
             ) == 4

      Cluster.TdLm.clone_relations(original_id, cloned_id, target_type, claims)

      assert length(
               Resources.list_relations(%{
                 "target_type" => target_type,
                 "source_id" => cloned_id
               })
             ) == 4

      Application.put_env(:td_cluster, TdCluster.ClusterHandler, MockClusterHandler)
    end

    test "clone_relations copy relations to new implementation with the same status", %{
      claims: claims
    } do
      Application.put_env(:td_cluster, TdCluster.ClusterHandler, TdCluster.ClusterHandlerImpl)
      original_id = 7777
      cloned_id = 5555
      source_type = "implementation_ref"
      target_type = "business_concept"

      insert(:relation,
        source_id: original_id,
        source_type: source_type,
        target_type: target_type,
        target_id: 1
      )

      Cluster.TdLm.clone_relations(original_id, cloned_id, target_type, claims)

      cloned_relations =
        Resources.list_relations(%{
          "target_type" => target_type,
          "source_id" => cloned_id
        })

      assert Enum.map(cloned_relations, & &1.status) == [nil]
    end
  end

  test "clone_relations copy relations to new implementation with tag", %{claims: claims} do
    Application.put_env(:td_cluster, TdCluster.ClusterHandler, TdCluster.ClusterHandlerImpl)
    original_id = 7777
    cloned_id = 5555
    source_type = "implementation_ref"
    target_type = "business_concept"
    %{id: tag_id} = tag = insert(:tag, value: %{"type" => "bar", "target_type" => "foo"})

    insert(:relation,
      source_id: original_id,
      source_type: source_type,
      target_type: target_type,
      tag: tag
    )

    Cluster.TdLm.clone_relations(original_id, cloned_id, target_type, claims)

    assert [%{tag_id: ^tag_id}] =
             Resources.list_relations(%{
               "target_type" => target_type,
               "source_id" => cloned_id
             })

    Application.put_env(:td_cluster, TdCluster.ClusterHandler, MockClusterHandler)
  end
end
