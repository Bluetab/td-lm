defmodule TdLmWeb.TagControllerTest do
  use TdLmWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  setup %{conn: conn} do
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "GET /api/tags" do
    @tag :admin_authenticated
    test "lists tags", %{conn: conn, swagger_schema: schema} do
      %{id: id} = insert(:tag)

      assert %{"data" => data} =
               conn
               |> get(Routes.tag_path(conn, :index))
               |> validate_resp_schema(schema, "TagsResponse")
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "GET /api/tags/:id" do
    @tag :admin_authenticated
    test "renders tag when data is valid", %{conn: conn, swagger_schema: schema} do
      %{id: id, value: value} = insert(:tag)

      assert %{"data" => data} =
               conn
               |> get(Routes.tag_path(conn, :show, id))
               |> validate_resp_schema(schema, "TagResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "value" => ^value} = data
    end

    @tag :admin_authenticated
    test "returns not found if tag does not exist", %{conn: conn} do
      assert_error_sent(:not_found, fn -> get(conn, Routes.tag_path(conn, :show, 123)) end)
    end
  end

  describe "POST /api/tags/search" do
    @tag :admin_authenticated
    test "search tags", %{conn: conn, swagger_schema: schema} do
      %{id: id} = insert(:tag, value: %{"target_type" => "ingest", "type" => "ingest"})

      params = %{"value" => %{target_type: "ingest"}}

      assert %{"data" => data} =
               conn
               |> post(Routes.tag_path(conn, :search), params)
               |> validate_resp_schema(schema, "TagsResponse")
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "POST /api/tags" do
    @tag :admin_authenticated
    test "renders tag when data is valid", %{conn: conn, swagger_schema: schema} do
      params = string_params_for(:tag)

      assert %{"data" => data} =
               conn
               |> post(Routes.tag_path(conn, :create), %{"tag" => params})
               |> validate_resp_schema(schema, "TagResponse")
               |> json_response(:created)

      assert Map.delete(data, "id") == params
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      params = string_params_for(:tag) |> Map.put("value", "string")

      assert %{"errors" => errors} =
               conn
               |> post(Routes.tag_path(conn, :create), %{"tag" => params})
               |> json_response(:unprocessable_entity)
    end
  end

  describe "DELETE /api/tags/:id" do
    @tag :admin_authenticated
    test "deletes chosen tag", %{conn: conn} do
      %{id: id} = insert(:tag)

      assert conn
             |> delete(Routes.tag_path(conn, :delete, id))
             |> response(:no_content)
    end
  end
end
