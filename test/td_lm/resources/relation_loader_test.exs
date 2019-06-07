defmodule TdLm.RelationLoaderTest do
  use TdLm.DataCase

  alias TdLm.RelationLoader
  alias TdLm.Resources
  alias TdPerms.MockBusinessConceptCache

  setup_all do
    start_supervised(MockBusinessConceptCache)
    :ok
  end

  describe "relations loader" do
    test "load_relation_cache writes to cache only the count of relations from business_concept to data_field" do
      insert_relation()

      insert_relation(%{
        source_id: "888",
        source_type: "business_concept",
        target_id: "8888",
        target_type: "data_field"
      })

      insert_relation(%{
        source_id: "1",
        source_type: "invalid_type",
        target_id: "2",
        target_type: "data_field"
      })

      RelationLoader.load()
      # waits for loader to complete
      RelationLoader.ping()

      cache_content = MockBusinessConceptCache.get_full_cache()

      expected_content = %{
        "business_concept:8" => %{link_count: 0},
        "business_concept:888" => %{link_count: 1},
        "business_concept:1" => %{link_count: 0}
      }

      assert cache_content == expected_content
    end
  end

  defp insert_relation(attrs \\ %{}) do
    relation = %{
      context: %{},
      source_id: "8",
      source_type: "business_concept",
      target_id: "88",
      target_type: "target_type"
    }

    attrs
    |> Enum.into(relation)
    |> Resources.create_relation()
  end
end
