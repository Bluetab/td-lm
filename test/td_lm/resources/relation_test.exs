defmodule TdLm.Resources.RelationTest do
  use TdLm.DataCase

  alias TdLm.Repo
  alias TdLm.Resources.Relation

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
