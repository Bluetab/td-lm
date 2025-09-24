defmodule TdLm.Search.StoreTest do
  use TdLm.DataCase

  alias TdCluster.TestHelpers.TdDdMock
  alias TdLm.Resources.Relation
  alias TdLm.Search.Store

  describe "stream/1" do
    test "stream over all relations" do
      %{id: concept_id} = CacheHelpers.put_concept()
      %{id: structure_id} = CacheHelpers.put_structure()

      Enum.each(1..2, fn _ ->
        generate_relation(%{
          source_id: concept_id,
          target_id: structure_id
        })
      end)

      generate_relation(%{source_type: "non_business_concept"})
      generate_relation(%{target_type: "non_data_structure"})
      generate_relation(%{deleted_at: DateTime.utc_now()})

      TdDdMock.log_start_stream(&Mox.expect/4, 2, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 2, :ok)

      {:ok, to_index} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream()
          |> Enum.to_list()
        end)

      assert Enum.count(to_index) == 2

      assert Enum.all?(to_index, fn r ->
               r.source_type == "business_concept" and
                 r.target_type == "data_structure" and
                 is_nil(r.deleted_at)
             end)
    end

    test "preload tags relations" do
      %{id: concept_id} = CacheHelpers.put_concept()
      %{id: structure_id} = CacheHelpers.put_structure()
      tag = insert(:tag)

      generate_relation(%{
        source_id: concept_id,
        target_id: structure_id,
        tag: tag
      })

      TdDdMock.log_start_stream(&Mox.expect/4, 1, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 1, :ok)

      {:ok, [%{tag: tag_index}]} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream()
          |> Enum.to_list()
        end)

      assert tag_index == tag
    end

    test "enriches with source and target data" do
      %{id: concept_id, name: concept_name} = CacheHelpers.put_concept(name: "concept_name")
      %{id: structure_id, name: structure_name} = CacheHelpers.put_structure()

      generate_relation(%{
        source_type: "business_concept",
        source_id: concept_id,
        target_type: "data_structure",
        target_id: structure_id
      })

      TdDdMock.log_start_stream(&Mox.expect/4, 1, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 1, :ok)

      {:ok, [to_index]} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream()
          |> Enum.to_list()
        end)

      assert %{
               source_type: "business_concept",
               source_id: ^concept_id,
               source_data: %{name: ^concept_name},
               target_type: "data_structure",
               target_id: ^structure_id,
               target_data: %{name: ^structure_name}
             } = to_index
    end
  end

  describe "stream/2" do
    test "stream over given relations ids" do
      %{id: concept_id} = CacheHelpers.put_concept()
      %{id: structure_id} = CacheHelpers.put_structure()

      [id_1, id_2 | _] =
        Enum.map(1..5, fn _ ->
          generate_relation(%{
            source_id: concept_id,
            target_id: structure_id
          }).id
        end)

      %{id: non_bc_id} = generate_relation(%{source_type: "non_business_concept"})
      %{id: non_ds_id} = generate_relation(%{target_type: "non_data_structure"})
      %{id: deleted_id} = generate_relation(%{deleted_at: DateTime.utc_now()})

      ids = [id_1, id_2, non_bc_id, non_ds_id, deleted_id]

      TdDdMock.log_start_stream(&Mox.expect/4, 2, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 2, :ok)

      {:ok, to_index} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream(ids)
          |> Enum.to_list()
        end)

      assert Enum.count(to_index) == 2

      assert Enum.all?(to_index, fn r ->
               r.source_type == "business_concept" and
                 r.target_type == "data_structure" and
                 is_nil(r.deleted_at)
             end)
    end

    test "enriches with source and target data" do
      %{id: concept_id, name: concept_name} = CacheHelpers.put_concept(name: "concept_name")

      %{id: structure_id, name: structure_name} = CacheHelpers.put_structure()

      %{id: relation_id} =
        generate_relation(%{
          source_type: "business_concept",
          source_id: concept_id,
          target_type: "data_structure",
          target_id: structure_id
        })

      TdDdMock.log_start_stream(&Mox.expect/4, 1, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 1, :ok)

      {:ok, [to_index]} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream([relation_id])
          |> Enum.to_list()
        end)

      assert %{
               source_type: "business_concept",
               source_id: ^concept_id,
               source_data: %{name: ^concept_name},
               target_type: "data_structure",
               target_id: ^structure_id,
               target_data: %{name: ^structure_name}
             } = to_index
    end
  end

  defp generate_relation(attrs) do
    relation_attrs =
      %{
        source_type: "business_concept",
        target_type: "data_structure",
        deleted_at: nil
      }
      |> Map.merge(attrs)
      |> Keyword.new()

    insert(:relation, relation_attrs)
  end
end
