defmodule TdLm.ResourcesTest do
  use TdLm.DataCase

  alias TdLm.Resources

  describe "relations" do
    alias TdLm.Resources.Relation

    @valid_attrs %{context: %{}, relation_type: "some relation_type", source_id: "some source_id", source_type: "some source_type", target_id: "some target_id", target_type: "some target_type"}
    @update_attrs %{relation_type: "some updated relation_type", source_id: "some updated source_id", source_type: "some updated source_type", target_id: "some updated target_id", target_type: "some updated target_type"}
    @invalid_attrs %{source_id: nil, source_type: nil, target_id: nil, target_type: nil}

    def relation_fixture(attrs \\ %{}) do
      {:ok, relation} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Resources.create_relation()

      relation
    end

    test "list_relations/0 returns all relations" do
      relation = relation_fixture()
      assert Resources.list_relations() == [relation]
    end

    test "get_relation!/1 returns the relation with given id" do
      relation = relation_fixture()
      assert Resources.get_relation!(relation.id) == relation
    end

    test "create_relation/1 with valid data creates a relation" do
      assert {:ok, %Relation{} = relation} = Resources.create_relation(@valid_attrs)
      assert relation.source_id == "some source_id"
      assert relation.source_type == "some source_type"
      assert relation.target_id == "some target_id"
      assert relation.target_type == "some target_type"
      assert relation.context == %{}
    end

    test "create_relation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Resources.create_relation(@invalid_attrs)
    end

    test "update_relation/2 with valid data updates the relation" do
      relation = relation_fixture()
      assert {:ok, relation} = Resources.update_relation(relation, @update_attrs)
      assert %Relation{} = relation
      assert relation.source_id == "some updated source_id"
      assert relation.source_type == "some updated source_type"
      assert relation.target_id == "some updated target_id"
      assert relation.target_type == "some updated target_type"
      assert relation.context == %{}
    end

    test "update_relation/2 with invalid data returns error changeset" do
      relation = relation_fixture()
      assert {:error, %Ecto.Changeset{}} = Resources.update_relation(relation, @invalid_attrs)
      assert relation == Resources.get_relation!(relation.id)
    end

    test "delete_relation/1 deletes the relation" do
      relation = relation_fixture()
      assert {:ok, %Relation{}} = Resources.delete_relation(relation)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_relation!(relation.id) end
    end

    test "change_relation/1 returns a relation changeset" do
      relation = relation_fixture()
      assert %Ecto.Changeset{} = Resources.change_relation(relation)
    end
  end

  describe "tags" do
    alias TdLm.Resources.Tag

    @valid_attrs %{value: %{}}
    @update_attrs %{value: %{}}
    @invalid_attrs %{value: nil}

    def tag_fixture(attrs \\ %{}) do
      {:ok, tag} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Resources.create_tag()

      tag
    end

    test "list_tags/0 returns all tags" do
      tag = tag_fixture()
      assert Resources.list_tags() == [tag]
    end

    test "get_tag!/1 returns the tag with given id" do
      tag = tag_fixture()
      assert Resources.get_tag!(tag.id) == tag
    end

    test "create_tag/1 with valid data creates a tag" do
      assert {:ok, %Tag{} = tag} = Resources.create_tag(@valid_attrs)
      assert tag.value == %{}
    end

    test "create_tag/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Resources.create_tag(@invalid_attrs)
    end

    test "update_tag/2 with valid data updates the tag" do
      tag = tag_fixture()
      assert {:ok, tag} = Resources.update_tag(tag, @update_attrs)
      assert %Tag{} = tag
      assert tag.value == %{}
    end

    test "update_tag/2 with invalid data returns error changeset" do
      tag = tag_fixture()
      assert {:error, %Ecto.Changeset{}} = Resources.update_tag(tag, @invalid_attrs)
      assert tag == Resources.get_tag!(tag.id)
    end

    test "delete_tag/1 deletes the tag" do
      tag = tag_fixture()
      assert {:ok, %Tag{}} = Resources.delete_tag(tag)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_tag!(tag.id) end
    end

    test "change_tag/1 returns a tag changeset" do
      tag = tag_fixture()
      assert %Ecto.Changeset{} = Resources.change_tag(tag)
    end
  end
end
