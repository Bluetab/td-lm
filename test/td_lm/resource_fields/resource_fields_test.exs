defmodule TdDq.ResourceLinksTest do
  use TdLm.DataCase
  alias TdLm.ResourceLinks
  alias TdLm.ResourceLinks.ResourceLink

  describe "resource_links" do

    @list_rs_links [%{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 1", "Field" => "Series name 1"}},
      %{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 2", "Field" => "Series name 2"}},
      %{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 3", "Field" => "Series name 3"}}]

    defp fixture_valid_resource_link do
      %{resource_id: "BC ID 1", resource_type: "business_concept",
        field: %{"ou" => "World Dev Indicators", "Field" => "Series name"}}
    end

    defp list_fixture do
      @list_rs_links
        |> Enum.map(&(ResourceLinks.create_resource_link(&1)))
    end

    defp fixture_create_bc do
      {:ok, result} = fixture_valid_resource_link()
       |> ResourceLinks.create_resource_link
      result
    end

    test "create_resource_link/1 with valid data creates a resouce_link" do
      valid_resource_link = fixture_valid_resource_link()
      {:ok, %ResourceLink{} = result} =
        valid_resource_link
          |> ResourceLinks.create_resource_link
      assert result.resource_id == valid_resource_link.resource_id &&
      result.resource_type == valid_resource_link.resource_type &&
      result.field == valid_resource_link.field

      result_query = ResourceLinks.get_resource_link!(result.id)
      assert result.id == result_query.id &&
      result.resource_id == result_query.resource_id &&
      result.resource_type == result_query.resource_type &&
      result.field == result_query.field

    end

    test "create_resource_link/1 having not field in data returns an error" do
      assert {:error, %Ecto.Changeset{}} =
        fixture_valid_resource_link()
        |> Map.delete(:field)
        |> ResourceLinks.create_resource_link
    end

    test "list_resource_links/2 returns a list of fields for a given resource id" do
      list_fixture()
      test_id = "1"
      resource_type = "business_concept"
      result_list = ResourceLinks.list_resource_links(test_id, resource_type)
      assert length(result_list) == length(@list_rs_links)
      assert Enum.all?(result_list, &(&1.resource_id == test_id))
      assert Enum.all?(result_list, &(&1.resource_type == resource_type))
    end

    test "delete_resource_link/1 deletes the expected resource_link" do
      created_resource_link = fixture_create_bc()
      test_id = "1"
      resource_type = "business_concept"
      ResourceLinks.delete_resource_link(created_resource_link)
      assert Enum.empty?(ResourceLinks.list_resource_links(test_id, resource_type))
    end
  end
end
