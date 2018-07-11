defmodule TdDq.ResourceFieldsTest do
  use TdLm.DataCase
  alias TdLm.ResourceFields
  alias TdLm.ResourceFields.ResourceField

  describe "resource_fields" do

    defp fixture_valid_resource_field do
      %{resource_id: "BC ID 1", resource_type: "business_concept",
        field: %{"ou" => "World Dev Indicators", "Field" => "Series name"}}
    end

    test "create_resource_field/1 with valid data creates a resouce_field" do
      valid_resource_field = fixture_valid_resource_field()
      {:ok, %ResourceField{} = result} =
        valid_resource_field
          |> ResourceFields.create_resource_field
      assert result.resource_id == valid_resource_field.resource_id &&
      result.resource_type == valid_resource_field.resource_type &&
      result.field == valid_resource_field.field
    end

    test "create_resource_field/1 having not field in data returns an error" do
      assert {:error, %Ecto.Changeset{}} =
        fixture_valid_resource_field()
        |> Map.delete(:field)
        |> ResourceFields.create_resource_field
    end

  end
end
