defmodule TdLmWeb.RelationControllerTest do
  use TdLmWeb.ConnCase

  alias TdLm.Resources
  alias TdLm.Resources.Relation

  import TdLmWeb.Authentication, only: :functions

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @create_attrs %{
    relation_type: "some relation_type",
    source_id: "some source_id",
    source_type: "some source_type",
    target_id: "some target_id",
    target_type: "some target_type"
  }
  @update_attrs %{
    relation_type: "some updated relation_type",
    source_id: "some updated source_id",
    source_type: "some updated source_type",
    target_id: "some updated target_id",
    target_type: "some updated target_type"
  }
  @invalid_attrs %{
    relation_type: nil,
    source_id: nil,
    source_type: nil,
    target_id: nil,
    target_type: nil
  }

  def fixture(:relation) do
    {:ok, relation} = Resources.create_relation(@create_attrs)
    relation
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all relations", %{conn: conn} do
      conn = get(conn, relation_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create relation" do
    @tag :admin_authenticated
    test "renders relation when data is valid", %{conn: conn} do
      conn = post(conn, relation_path(conn, :create), relation: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, relation_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "relation_type" => "some relation_type",
               "source_id" => "some source_id",
               "source_type" => "some source_type",
               "target_id" => "some target_id",
               "target_type" => "some target_type"
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, relation_path(conn, :create), relation: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update relation" do
    setup [:create_relation]

    @tag :admin_authenticated
    test "renders relation when data is valid", %{
      conn: conn,
      relation: %Relation{id: id} = relation
    } do
      conn = put(conn, relation_path(conn, :update, relation), relation: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, relation_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "relation_type" => "some updated relation_type",
               "source_id" => "some updated source_id",
               "source_type" => "some updated source_type",
               "target_id" => "some updated target_id",
               "target_type" => "some updated target_type"
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, relation: relation} do
      conn = put(conn, relation_path(conn, :update, relation), relation: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete relation" do
    setup [:create_relation]

    @tag :admin_authenticated
    test "deletes chosen relation", %{conn: conn, relation: relation} do
      conn = delete(conn, relation_path(conn, :delete, relation))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, relation_path(conn, :show, relation))
      end)
    end
  end

  defp create_relation(_) do
    relation = fixture(:relation)
    {:ok, relation: relation}
  end
end
