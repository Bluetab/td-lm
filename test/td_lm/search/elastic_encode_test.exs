defmodule TdLm.Search.ElasticEncodeTest do
  use TdLmWeb.ConnCase

  alias Elasticsearch.Document

  describe "encode/1" do
    test "Encode the correct information from relations" do
      %{value: %{"type" => type}} = tag = insert(:tag)

      %{
        id: id,
        source_type: source_type,
        target_type: target_type,
        source_id: source_id,
        target_id: target_id,
        origin: origin,
        status: status,
        source_data: source_data,
        target_data: target_data
      } =
        relation = generate_relation(%{origin: "test_origin", status: "pending", tag: tag})

      source_name = Map.get(source_data, :name)
      target_name = Map.get(target_data, :name)
      domain_ids = Map.get(source_data, :domain_ids) ++ Map.get(target_data, :domain_ids)
      source_domain_ids = Map.get(source_data, :domain_ids)
      target_domain_ids = Map.get(target_data, :domain_ids)

      assert %{
               id: ^id,
               source_type: ^source_type,
               target_type: ^target_type,
               source_id: ^source_id,
               target_id: ^target_id,
               origin: ^origin,
               status: ^status,
               domain_ids: ^domain_ids,
               source_domain_ids: ^source_domain_ids,
               target_domain_ids: ^target_domain_ids,
               source_name: ^source_name,
               target_name: ^target_name,
               tag_type: ^type
             } =
               Document.encode(relation)
    end
  end

  defp generate_relation(attrs) do
    %{id: source_domain_id} = CacheHelpers.put_domain()
    %{id: target_domain_id} = CacheHelpers.put_domain()

    relation_attrs =
      %{
        source_type: "business_concept",
        target_type: "data_structure",
        deleted_at: nil
      }
      |> Map.merge(attrs)
      |> Keyword.new()

    insert(:relation, relation_attrs)
    |> Map.put(:source_data, %{name: "Source", domain_ids: [source_domain_id]})
    |> Map.put(:target_data, %{name: "Target", domain_ids: [target_domain_id]})
  end
end
