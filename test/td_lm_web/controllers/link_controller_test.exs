defmodule TdLmWeb.LinkControllerTest do
  use TdLmWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
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
              :add_field,
              fixture_params.business_concept_id,
              fixture_params.domain_id
            ),
            field: fixture_params.field
          )
        resp = json_response(conn, 200)
        validate_resp_schema(conn, schema, "ConceptFieldResponse")
        {resp_bc_id, _} = Integer.parse(resp["concept"])
        assert fixture_params.business_concept_id == resp_bc_id
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
              :add_field,
              fixture_params.business_concept_id,
              fixture_params.domain_id
            ),
            field: fixture_params.field
          )
        resp = json_response(conn, 403)
        assert resp["errors"]["detail"] == @error_messages.unauthorized
    end
  end

  defp add_request_fixture do
    %{business_concept_id: 1, domain_id: 1, field: %{"ou" => "World Dev Indicators", "Field" => "Series name"}}
  end

end
