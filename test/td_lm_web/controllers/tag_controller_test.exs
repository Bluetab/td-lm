defmodule TdLmWeb.TagControllerTest do
  use TdLmWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdLm.Resources
  alias TdLm.Resources.Tag

  import TdLmWeb.Authentication, only: :functions

  @create_attrs %{value: %{type: "test"}}
  @update_attrs %{value: %{type: "updated test"}}
  @invalid_attrs %{value: nil}

  def fixture(:tag) do
    {:ok, tag} = Resources.create_tag(@create_attrs)
    tag
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all tags", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, tag_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
      validate_resp_schema(conn, schema, "TagsResponse")
    end
  end

  describe "create tag" do
    @tag :admin_authenticated
    test "renders tag when data is valid", %{conn: conn, swagger_schema: schema} do
      conn = post(conn, tag_path(conn, :create), tag: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "TagResponse")

      conn = recycle_and_put_headers(conn)

      conn = get(conn, tag_path(conn, :show, id))
      assert json_response(conn, 200)["data"] == %{"id" => id, "value" => %{"type" => "test"}}
      validate_resp_schema(conn, schema, "TagResponse")
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, tag_path(conn, :create), tag: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update tag" do
    setup [:create_tag]

    @tag :admin_authenticated
    test "renders tag when data is valid", %{conn: conn, swagger_schema: schema, tag: %Tag{id: id} = tag} do
      conn = put(conn, tag_path(conn, :update, tag), tag: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      validate_resp_schema(conn, schema, "TagResponse")

      conn = recycle_and_put_headers(conn)

      conn = get(conn, tag_path(conn, :show, id))
      assert json_response(conn, 200)["data"] == %{"id" => id, "value" => %{"type" => "updated test"}}
      validate_resp_schema(conn, schema, "TagResponse")
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, tag: tag} do
      conn = put(conn, tag_path(conn, :update, tag), tag: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete tag" do
    setup [:create_tag]

    @tag :admin_authenticated
    test "deletes chosen tag", %{conn: conn, tag: tag} do
      conn = delete(conn, tag_path(conn, :delete, tag))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, tag_path(conn, :show, tag))
      end)
    end
  end

  defp create_tag(_) do
    tag = fixture(:tag)
    {:ok, tag: tag}
  end
end
