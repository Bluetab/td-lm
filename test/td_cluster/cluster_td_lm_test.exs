defmodule TdCluster.ClusterTdLmTest do
  use TdLm.DataCase
  alias TdCache.Redix
  alias TdCluster.Cluster, as: Cluster
  alias TdLm.Resources
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

  describe "test Cluster.TdLm functions" do
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
    end
  end
end
