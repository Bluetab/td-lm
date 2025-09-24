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

    test "validate status rejects invalid value" do
      assert %{valid?: false, errors: errors} =
               :relation
               |> params_for()
               |> Map.put(:status, "invalid")
               |> Relation.changeset()

      assert errors[:status] ==
               {"is invalid", [{:validation, :inclusion}, {:enum, ["pending"]}]}
    end

    test "validate status accepts status with nil" do
      assert %{valid?: true} =
               :relation
               |> params_for()
               |> Map.put(:status, nil)
               |> Relation.changeset()
    end

    test "validate status accepts allowed statuses" do
      assert %{valid?: true} =
               :relation
               |> params_for()
               |> Map.put(:status, "pending")
               |> Relation.changeset()
    end

    for status <- ["approved", "rejected"] do
      @tag status: status
      test "validate status rejects not allowed status #{status}", %{status: status} do
        assert %{valid?: false, errors: errors} =
                 :relation
                 |> params_for()
                 |> Map.put(:status, status)
                 |> Relation.changeset()

        assert errors[:status] ==
                 {"is invalid", [{:validation, :inclusion}, {:enum, ["pending"]}]}
      end
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

  describe "status_changeset/1" do
    for status <- ["approved", "rejected"] do
      @tag status: status
      test "allows pending status to #{status}", %{status: status} do
        relation = insert(:relation, status: "pending")

        assert {:ok, relation} =
                 relation
                 |> Relation.status_changeset(%{status: status})
                 |> Repo.update()

        assert relation.status == status
      end
    end

    for status <- ["rejected", "approved", nil] do
      @tag status: status
      test "does not allow #{if is_nil(status), do: "nil", else: status} status to change", %{
        status: status
      } do
        relation =
          insert(:relation, status: status)

        assert {:error, changeset} =
                 relation
                 |> Relation.status_changeset(%{status: "approved"})
                 |> Repo.update()

        assert changeset.valid? == false

        status_key =
          if is_nil(status), do: :status_nil, else: String.to_atom("status_#{status}")

        assert changeset.errors[status_key] ==
                 {"is not allowed to change #{if is_nil(status), do: "nil", else: status} status",
                  []}
      end
    end
  end
end
