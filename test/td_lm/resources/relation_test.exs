defmodule TdLm.Resources.RelationTest do
  use TdLm.DataCase

  alias TdLm.Repo
  alias TdLm.Resources.Relation

  @unsafe "javascript:alert(document)"

  setup do
    tag = insert(:tag)

    relation = insert(:relation, tag: tag)
    [relation: relation, tag: tag]
  end

  describe "changeset/1" do
    test "validates content is safe" do
      assert %{valid?: false, errors: errors} =
               :relation
               |> params_for()
               |> Map.put(:context, %{"foo" => @unsafe})
               |> Relation.changeset()

      assert errors[:context] == {"invalid content", []}
    end

    test "is inserted successfully", %{tag: %{id: id_tag}} do
      assert {:ok, relation} =
               :relation
               |> params_for()
               |> Map.put(:tag_id, id_tag)
               |> Relation.changeset()
               |> Repo.insert()

      assert %{tag_id: id_relation_tag} = relation
      assert id_relation_tag == id_tag
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

    test "is updated successfully", %{relation: relation} do
      %{id: tag_id} = insert(:tag)

      params =
        :relation
        |> params_for()
        |> Map.put(:tag_id, tag_id)

      assert {:ok, relation} =
               relation
               |> Relation.changeset(params)
               |> Repo.update()

      assert %{tag_id: id_relation_tag} = relation
      assert id_relation_tag == tag_id
    end
  end
end
