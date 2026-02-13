defmodule TdLm.Search.StoreTest do
  use TdLm.DataCase

  alias TdCluster.TestHelpers.TdDdMock
  alias TdLm.Resources.Relation
  alias TdLm.Search.Store

  describe "stream/1" do
    setup do
      [
        concept: %{business_concept_id: System.unique_integer([:positive]), name: "concept_name"},
        structure: %{
          data_structure_id: System.unique_integer([:positive]),
          name: "structure_name"
        }
      ]
    end

    test "stream over all relations", %{concept: concept, structure: structure} do
      bg_store_mock = :bg_mock
      bg_schema_mock = :bg_schema_mock
      dd_store_mock = :dd_mock
      dd_schema_mock = :dd_schema_mock

      Enum.each(1..2, fn _ ->
        generate_relation(%{
          source_id: concept.business_concept_id,
          target_id: structure.data_structure_id
        })
      end)

      generate_relation(%{source_type: "non_business_concept"})
      generate_relation(%{target_type: "non_data_structure"})

      TdDdMock.log_start_stream(&Mox.expect/4, 2, :ok)

      Mox.expect(MockClusterHandler, :call, 4, fn
        :bg, TdBg.BusinessConcept.Search, :store, [] ->
          {:ok, %{schema: bg_schema_mock, store: bg_store_mock}}

        :dd, TdDd.DataStructures.Search, :store, [] ->
          {:ok, %{schema: dd_schema_mock, store: dd_store_mock}}

        :bg, ^bg_store_mock, :fetch, [^bg_schema_mock, _param_concept_ids] ->
          {:ok, [concept]}

        :dd, ^dd_store_mock, :fetch, [^dd_schema_mock, _param_data_structure_ids] ->
          {:ok, [structure]}
      end)

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

    test "remove relations with missing source or target data over all relations", %{
      structure: %{data_structure_id: structure_id} = structure
    } do
      concept_id = System.unique_integer([:positive])
      bg_store_mock = :bg_mock
      bg_schema_mock = :bg_schema_mock
      dd_store_mock = :dd_mock
      dd_schema_mock = :dd_schema_mock

      generate_relation(%{source_id: concept_id, target_id: structure_id})
      generate_relation(%{source_id: concept_id + 100_000, target_id: structure_id + 100_000})

      TdDdMock.log_start_stream(&Mox.expect/4, 2, :ok)

      Mox.expect(MockClusterHandler, :call, 4, fn
        :bg, TdBg.BusinessConcept.Search, :store, [] ->
          {:ok, %{schema: bg_schema_mock, store: bg_store_mock}}

        :dd, TdDd.DataStructures.Search, :store, [] ->
          {:ok, %{schema: dd_schema_mock, store: dd_store_mock}}

        :bg, ^bg_store_mock, :fetch, [^bg_schema_mock, _param_concept_ids] ->
          {:ok, []}

        :dd, ^dd_store_mock, :fetch, [^dd_schema_mock, _param_data_structure_ids] ->
          {:ok, [structure]}
      end)

      TdDdMock.log_progress(&Mox.expect/4, 2, :ok)

      {:ok, to_index} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream()
          |> Enum.to_list()
        end)

      assert Enum.count(to_index) == 1
    end

    test "preload tags relations", %{concept: concept, structure: structure} do
      bg_store_mock = :bg_mock
      bg_schema_mock = :bg_schema_mock
      dd_store_mock = :dd_mock
      dd_schema_mock = :dd_schema_mock

      tag = insert(:tag)

      generate_relation(%{
        source_id: concept.business_concept_id,
        target_id: structure.data_structure_id,
        tag: tag
      })

      TdDdMock.log_start_stream(&Mox.expect/4, 1, :ok)

      Mox.expect(MockClusterHandler, :call, 4, fn
        :bg, TdBg.BusinessConcept.Search, :store, [] ->
          {:ok, %{schema: bg_schema_mock, store: bg_store_mock}}

        :dd, TdDd.DataStructures.Search, :store, [] ->
          {:ok, %{schema: dd_schema_mock, store: dd_store_mock}}

        :bg, ^bg_store_mock, :fetch, [^bg_schema_mock, _param_concept_ids] ->
          {:ok, [concept]}

        :dd, ^dd_store_mock, :fetch, [^dd_schema_mock, _param_data_structure_ids] ->
          {:ok, [structure]}
      end)

      TdDdMock.log_progress(&Mox.expect/4, 1, :ok)

      {:ok, [%{tag: tag_index}]} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream()
          |> Enum.to_list()
        end)

      assert tag_index == tag
    end

    test "enriches with source and target data", %{
      concept: %{business_concept_id: concept_id, name: concept_name} = concept,
      structure: %{data_structure_id: structure_id, name: structure_name} = structure
    } do
      bg_store_mock = :bg_mock
      bg_schema_mock = :bg_schema_mock
      dd_store_mock = :dd_mock
      dd_schema_mock = :dd_schema_mock

      generate_relation(%{
        source_type: "business_concept",
        source_id: concept_id,
        target_type: "data_structure",
        target_id: structure_id
      })

      TdDdMock.log_start_stream(&Mox.expect/4, 1, :ok)

      Mox.expect(MockClusterHandler, :call, 4, fn
        :bg, TdBg.BusinessConcept.Search, :store, [] ->
          {:ok, %{schema: bg_schema_mock, store: bg_store_mock}}

        :dd, TdDd.DataStructures.Search, :store, [] ->
          {:ok, %{schema: dd_schema_mock, store: dd_store_mock}}

        :bg, ^bg_store_mock, :fetch, [^bg_schema_mock, _param_concept_ids] ->
          {:ok, [concept]}

        :dd, ^dd_store_mock, :fetch, [^dd_schema_mock, _param_data_structure_ids] ->
          {:ok, [structure]}
      end)

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
    setup do
      [
        concept: %{business_concept_id: System.unique_integer([:positive]), name: "concept_name"},
        structure: %{
          data_structure_id: System.unique_integer([:positive]),
          name: "structure_name"
        }
      ]
    end

    test "stream over given relations ids", %{concept: concept, structure: structure} do
      bg_store_mock = :bg_mock
      bg_schema_mock = :bg_schema_mock
      dd_store_mock = :dd_mock
      dd_schema_mock = :dd_schema_mock

      [id_1, id_2 | _] =
        Enum.map(1..5, fn _ ->
          generate_relation(%{
            source_id: concept.business_concept_id,
            target_id: structure.data_structure_id
          }).id
        end)

      %{id: non_bc_id} = generate_relation(%{source_type: "non_business_concept"})
      %{id: non_ds_id} = generate_relation(%{target_type: "non_data_structure"})

      %{id: deleted_id} =
        generate_relation(%{
          deleted_at: DateTime.utc_now(),
          source_id: concept.business_concept_id
        })

      ids = [id_1, id_2, non_bc_id, non_ds_id, deleted_id]

      TdDdMock.log_start_stream(&Mox.expect/4, 3, :ok)

      Mox.expect(MockClusterHandler, :call, 4, fn
        :bg, TdBg.BusinessConcept.Search, :store, [] ->
          {:ok, %{schema: bg_schema_mock, store: bg_store_mock}}

        :dd, TdDd.DataStructures.Search, :store, [] ->
          {:ok, %{schema: dd_schema_mock, store: dd_store_mock}}

        :bg, ^bg_store_mock, :fetch, [^bg_schema_mock, _param_concept_ids] ->
          {:ok, [concept]}

        :dd, ^dd_store_mock, :fetch, [^dd_schema_mock, _param_data_structure_ids] ->
          {:ok, [structure]}
      end)

      TdDdMock.log_progress(&Mox.expect/4, 3, :ok)

      {:ok, to_index} =
        Repo.transaction(fn ->
          Relation
          |> Store.stream(ids)
          |> Enum.to_list()
        end)

      assert Enum.count(to_index) == 3

      assert Enum.all?(to_index, fn r ->
               r.source_type == "business_concept" and r.target_type == "data_structure"
             end)
    end

    test "enriches with source and target data", %{
      concept: %{name: concept_name, business_concept_id: concept_id} = concept,
      structure: %{data_structure_id: structure_id, name: structure_name} = structure
    } do
      bg_store_mock = :bg_mock
      bg_schema_mock = :bg_schema_mock
      dd_store_mock = :dd_mock
      dd_schema_mock = :dd_schema_mock

      %{id: relation_id} =
        generate_relation(%{
          source_type: "business_concept",
          source_id: concept_id,
          target_type: "data_structure",
          target_id: structure_id
        })

      TdDdMock.log_start_stream(&Mox.expect/4, 1, :ok)

      Mox.expect(MockClusterHandler, :call, 4, fn
        :bg, TdBg.BusinessConcept.Search, :store, [] ->
          {:ok, %{schema: bg_schema_mock, store: bg_store_mock}}

        :dd, TdDd.DataStructures.Search, :store, [] ->
          {:ok, %{schema: dd_schema_mock, store: dd_store_mock}}

        :bg, ^bg_store_mock, :fetch, [^bg_schema_mock, _param_concept_ids] ->
          {:ok, [concept]}

        :dd, ^dd_store_mock, :fetch, [^dd_schema_mock, _param_data_structure_ids] ->
          {:ok, [structure]}
      end)

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
