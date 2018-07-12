defmodule TdDq.ResourceFieldsTest do
  use TdLm.DataCase
  alias TdLm.ResourceFields
  alias TdLm.ResourceFields.ResourceField

  describe "resource_fields" do

    @list_rs_fields [%{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 1", "Field" => "Series name 1"}},
      %{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 2", "Field" => "Series name 2"}},
      %{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 3", "Field" => "Series name 3"}}]

    defp fixture_valid_resource_field do
      %{resource_id: "BC ID 1", resource_type: "business_concept",
        field: %{"ou" => "World Dev Indicators", "Field" => "Series name"}}
    end

    defp list_fixture do
      @list_rs_fields
        |> Enum.map(&(ResourceFields.create_resource_field(&1)))
    end

    defp fixture_create_bc do
      {:ok, result} = fixture_valid_resource_field()
       |> ResourceFields.create_resource_field
      result
    end

    test "create_resource_field/1 with valid data creates a resouce_field" do
      valid_resource_field = fixture_valid_resource_field()
      {:ok, %ResourceField{} = result} =
        valid_resource_field
          |> ResourceFields.create_resource_field
      assert result.resource_id == valid_resource_field.resource_id &&
      result.resource_type == valid_resource_field.resource_type &&
      result.field == valid_resource_field.field

      result_query = ResourceFields.get_resource_field!(result.id)
      assert result.id == result_query.id &&
      result.resource_id == result_query.resource_id &&
      result.resource_type == result_query.resource_type &&
      result.field == result_query.field

    end

    test "create_resource_field/1 having not field in data returns an error" do
      assert {:error, %Ecto.Changeset{}} =
        fixture_valid_resource_field()
        |> Map.delete(:field)
        |> ResourceFields.create_resource_field
    end

    test "list_resource_fields/2 returns a list of fields for a given resource id" do
      list_fixture()
      test_id = "1"
      resource_type = "business_concept"
      result_list = ResourceFields.list_resource_fields(test_id, resource_type)
      assert length(result_list) == length(@list_rs_fields)
      assert Enum.all?(result_list, &(&1.resource_id == test_id))
      assert Enum.all?(result_list, &(&1.resource_type == resource_type))
    end

    test "delete_resource_field/1 deletes the expected resource_field" do
      created_resource_field = fixture_create_bc()
      test_id = "1"
      resource_type = "business_concept"
      ResourceFields.delete_resource_field(created_resource_field)
      assert Enum.empty?(ResourceFields.list_resource_fields(test_id, resource_type))
    end
  end
end
