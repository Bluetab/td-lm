defmodule TdLm.Resources.RelationTest do
  use TdLm.DataCase

  alias TdLm.Repo
  alias TdLm.Resources.Relation

  @unsafe "javascript:alert(document)"

  setup do
    tags = Enum.map(1..5, fn _ -> insert(:tag) end)
    relation = insert(:relation, tags: tags)
    [relation: relation, tags: tags]
  end

  describe "changeset/1" do
    test "puts tags association", %{tags: tags} do
      tag_ids = Enum.map(tags, & &1.id)

      assert %{valid?: true, changes: changes} =
               :relation
               |> params_for()
               |> Map.put(:tag_ids, tag_ids)
               |> Relation.changeset()

      assert %{tags: tags} = changes
      assert Enum.map(tags, & &1.data.id) == tag_ids
    end

    test "validates content is safe" do
      assert %{valid?: false, errors: errors} =
               :relation
               |> params_for()
               |> Map.put(:context, %{"foo" => @unsafe})
               |> Relation.changeset()

      assert errors[:context] == {"invalid content", []}
    end

    test "is inserted successfully", %{tags: tags} do
      tag_ids = Enum.map(tags, & &1.id)

      assert {:ok, relation} =
               :relation
               |> params_for()
               |> Map.put(:tag_ids, tag_ids)
               |> Relation.changeset()
               |> Repo.insert()

      assert %{tags: tags} = relation
      assert Enum.map(tags, & &1.id) == tag_ids
    end
  end

  describe "changeset/2" do
    test "validates fields with valid values" do
      assert %{errors: []} =
               Relation.changeset(%Relation{}, %{
                 source_id: 123,
                 source_type: "business_concept",
                 target_id: 321,
                 target_type: "data_structure",
                 origin: "origin",
                 context: %{"foo" => "bar"}
               })
    end

    test "validates fields with nil origin" do
      assert %{errors: []} =
               Relation.changeset(%Relation{}, %{
                 source_id: 123,
                 source_type: "business_concept",
                 target_id: 321,
                 target_type: "data_structure",
                 origin: nil,
                 context: %{"foo" => "bar"}
               })
    end

    test "validates required fields" do
      assert %{errors: errors} = Relation.changeset(%Relation{}, %{})

      assert {_, [validation: :required]} = errors[:source_id]
      assert {_, [validation: :required]} = errors[:source_type]
      assert {_, [validation: :required]} = errors[:target_id]
      assert {_, [validation: :required]} = errors[:target_type]
    end

    test "validates field types" do
      assert %{errors: errors} =
               Relation.changeset(
                 %Relation{},
                 %{
                   source_id: false,
                   source_type: "stop_inventing",
                   target_id: "core",
                   target_type: false,
                   context: "invalid context"
                 }
               )

      assert {_, [{:type, :integer}, {:validation, :cast}]} = errors[:source_id]

      assert {_,
              [
                {:validation, :inclusion},
                {:enum,
                 [
                   "business_concept",
                   "data_field",
                   "data_structure",
                   "ingest",
                   "implementation_ref"
                 ]}
              ]} =
               errors[:source_type]

      assert {_, [{:type, :integer}, {:validation, :cast}]} = errors[:target_id]
      assert {_, [{:type, :string}, {:validation, :cast}]} = errors[:target_type]
      assert {_, [{:type, :map}, {:validation, :cast}]} = errors[:context]
    end

    test "replaces tags association", %{relation: relation} do
      %{id: new_tag_id} = insert(:tag)

      params =
        :relation
        |> params_for()
        |> Map.put(:tag_ids, [new_tag_id])

      assert %{valid?: true, changes: changes} = Relation.changeset(relation, params)

      assert %{tags: tags} = changes

      assert %{replace: old_tag_ids, update: [^new_tag_id]} =
               Enum.group_by(tags, & &1.action, & &1.data.id)

      assert Enum.all?(relation.tags, &(&1.id in old_tag_ids))
    end

    test "is updated successfully", %{relation: relation} do
      %{id: tag_id} = insert(:tag)

      params =
        :relation
        |> params_for()
        |> Map.put(:tag_ids, [tag_id])

      assert {:ok, relation} =
               relation
               |> Relation.changeset(params)
               |> Repo.update()

      assert %{tags: tags} = relation
      assert Enum.map(tags, & &1.id) == [tag_id]
    end
  end
end
