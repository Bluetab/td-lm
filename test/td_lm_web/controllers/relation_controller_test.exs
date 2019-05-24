defmodule TdLmWeb.RelationControllerTest do
  use TdLmWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdLm.Resources
  alias TdLm.Resources.Relation
  alias TdLmWeb.ApiServices.MockTdAuditService

  import TdLmWeb.Authentication, only: :functions

  setup_all do
    start_supervised(MockTdAuditService)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @create_attrs %{
    source_id: "some source_id",
    source_type: "some source_type",
    target_id: "some target_id",
    target_type: "some target_type"
  }
  @update_attrs %{
    source_id: "some updated source_id",
    source_type: "some updated source_type",
    target_id: "some updated target_id",
    target_type: "some updated target_type"
  }
  @invalid_attrs %{
    source_id: nil,
    source_type: nil,
    target_id: nil,
    target_type: nil
  }

  @ingest_source_attrs %{
    source_id: "source_id",
    source_type: "ingest",
    target_id: "target_id",
    target_type: "some target_type"
  }

  @user_name "not admin user"

  describe "search" do
    @tag :admin_authenticated
    test "search all relations", %{conn: conn, swagger_schema: schema} do
      conn = post(conn, Routes.relation_path(conn, :search, %{}))
      assert json_response(conn, 200)["data"] == []
      validate_resp_schema(conn, schema, "RelationsResponse")
    end
  end

  describe "search relation when user has not permissions" do
    setup [:create_no_perms_source_relation]

    @tag authenticated_user: @user_name
    test "search all relations", %{conn: conn, swagger_schema: schema, relation: relation} do
      conn = post(conn, Routes.relation_path(conn, :search, %{}))
      assert Enum.all?(json_response(conn, 200)["data"], &(&1.id != relation.id))
      validate_resp_schema(conn, schema, "RelationsResponse")
    end
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all relations", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.relation_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
      validate_resp_schema(conn, schema, "RelationsResponse")
    end
  end

  describe "create relation" do
    @tag :admin_authenticated
    test "renders relation when data is valid", %{conn: conn, swagger_schema: schema} do
      conn = post(conn, Routes.relation_path(conn, :create), relation: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "RelationResponse")

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.relation_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "source_id" => "some source_id",
               "source_type" => "some source_type",
               "target_id" => "some target_id",
               "target_type" => "some target_type",
               "context" => %{},
               "tags" => []
             }

      validate_resp_schema(conn, schema, "RelationResponse")
    end

    @tag authenticated_user: @user_name
    test "error when user has not permissions to create a relation", %{conn: conn} do
      conn = post(conn, Routes.relation_path(conn, :create), relation: @ingest_source_attrs)
      assert json_response(conn, 403)["errors"]["detail"] == "Invalid authorization"
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.relation_path(conn, :create), relation: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update relation" do
    setup [:create_no_perms_source_relation]

    @tag :admin_authenticated
    test "renders relation when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      relation: %Relation{id: id} = relation
    } do
      conn = put(conn, Routes.relation_path(conn, :update, relation), relation: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      validate_resp_schema(conn, schema, "RelationResponse")

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.relation_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "source_id" => "some updated source_id",
               "source_type" => "some updated source_type",
               "target_id" => "some updated target_id",
               "target_type" => "some updated target_type",
               "context" => %{},
               "tags" => []
             }

      validate_resp_schema(conn, schema, "RelationResponse")
    end

    @tag authenticated_user: @user_name
    test "error when user has not permissions to create a relation", %{
      conn: conn,
      relation: relation
    } do
      conn = put(conn, Routes.relation_path(conn, :update, relation), relation: @update_attrs)
      assert json_response(conn, 403)["errors"]["detail"] == "Invalid authorization"
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, relation: relation} do
      conn = put(conn, Routes.relation_path(conn, :update, relation), relation: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete relation" do
    setup [:create_no_perms_source_relation]

    @tag authenticated_user: @user_name
    test "error when user has not permissions to create a relation", %{
      conn: conn,
      relation: relation
    } do
      conn = delete(conn, Routes.relation_path(conn, :delete, relation))
      assert json_response(conn, 403)["errors"]["detail"] == "Invalid authorization"
    end

    @tag :admin_authenticated
    test "deletes chosen relation", %{conn: conn, relation: relation} do
      conn = delete(conn, Routes.relation_path(conn, :delete, relation))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, Routes.relation_path(conn, :show, relation))
      end)
    end
  end

  defp create_no_perms_source_relation(_) do
    {:ok, relation} = Resources.create_relation(@ingest_source_attrs)
    {:ok, relation: relation}
  end
end
