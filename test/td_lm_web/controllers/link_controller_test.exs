defmodule TdLmWeb.LinkControllerTest do
  use TdLmWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
  alias TdLm.ResourceFields
  alias TdLmWeb.ApiServices.MockTdAuditService

  setup_all do
    start_supervised MockTdAuditService
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @not_admin_user_name "MyNotAdminUser"
  @error_messages %{unauthorized: "Invalid authorization"}
  @list_rs_fields [%{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 1", "Field" => "Series name 1"}},
  %{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 2", "Field" => "Series name 2"}},
  %{resource_id: "1", resource_type: "business_concept", field: %{"ou" => "World Dev Indicators 3", "Field" => "Series name 3"}}]

  describe "create link" do
    @tag :admin_authenticated
    test "renders link when data is valid and user is authorized",
      %{conn: conn, swagger_schema: schema} do
        fixture_params = add_request_fixture()
        conn =
          post(
            conn,
            link_path(
              conn,
              :add_link,
              fixture_params.resource_type,
              fixture_params.resource_id
            ),
            field: fixture_params.field
          )
        resp = json_response(conn, 200)
        validate_resp_schema(conn, schema, "ResourceFieldResponse")
        {resp_rs_id, _} = Integer.parse(resp["resource_id"])
        assert fixture_params.resource_id == resp_rs_id
        assert fixture_params.resource_type == resp["resource_type"]
        assert fixture_params.field == resp["field"]
    end

    @tag authenticated_user: @not_admin_user_name
    test "renders errors when user has not permissions",
      %{conn: conn, swagger_schema: _schema} do
        fixture_params = add_request_fixture()
        conn =
          post(
            conn,
            link_path(
              conn,
              :add_link,
              fixture_params.resource_type,
              fixture_params.resource_id
            ),
            field: fixture_params.field
          )
        resp = json_response(conn, 403)
        assert resp["errors"]["detail"] == @error_messages.unauthorized
    end
  end

  describe "Query links for a given resource id and resource type" do
    @tag :admin_authenticated
    test "renders the list",
      %{conn: conn, swagger_schema: schema} do
        list_fixture()
        target_resource_id = "1"
        target_resource_type = "business_concept"
        conn =
          get(
            conn,
            link_path(
              conn,
              :get_links,
              target_resource_type,
              target_resource_id
            )
          )
        resp = json_response(conn, 200)
        validate_resp_schema(conn, schema, "ResourceFieldsResponse")
        assert length(resp["data"]) == length(@list_rs_fields)
        assert Enum.all?(resp["data"], &(&1["resource_id"] == target_resource_id))
        assert Enum.all?(resp["data"], &(&1["resource_type"] == target_resource_type))
    end
  end

  defp add_request_fixture do
    %{resource_id: 1, resource_type: "business_concept", field: %{"ou" => "World Dev Indicators", "Field" => "Series name"}}
  end

  defp list_fixture do
    @list_rs_fields
      |> Enum.map(&(ResourceFields.create_resource_field(&1)))
  end
end
