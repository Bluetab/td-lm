defmodule TdLmWeb.TagControllerTest do
  use TdLmWeb.ConnCase

  setup %{conn: conn} do
    start_supervised!(TdLm.Cache.LinkLoader)
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "GET /api/tags" do
    @tag authentication: [role: "admin"]
    test "lists tags", %{conn: conn} do
      %{id: id} = insert(:tag)

      assert %{"data" => data} =
               conn
               |> get(Routes.tag_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "GET /api/tags/:id" do
    @tag authentication: [role: "admin"]
    test "renders tag when data is valid", %{conn: conn} do
      %{id: id, value: value} = insert(:tag)

      assert %{"data" => data} =
               conn
               |> get(Routes.tag_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"id" => ^id, "value" => ^value} = data
    end

    @tag authentication: [role: "admin"]
    test "returns not found if tag does not exist", %{conn: conn} do
      assert_error_sent(:not_found, fn -> get(conn, Routes.tag_path(conn, :show, 123)) end)
    end
  end

  describe "POST /api/tags/search" do
    @tag authentication: [role: "admin"]
    test "search tags", %{conn: conn} do
      %{id: id} = insert(:tag, value: %{"target_type" => "ingest", "type" => "ingest"})

      params = %{"value" => %{target_type: "ingest"}}

      assert %{"data" => data} =
               conn
               |> post(Routes.tag_path(conn, :search), params)
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "POST /api/tags" do
    @tag authentication: [role: "admin"]
    test "renders tag when data is valid", %{conn: conn} do
      params = string_params_for(:tag)

      assert %{"data" => data} =
               conn
               |> post(Routes.tag_path(conn, :create), %{"tag" => params})
               |> json_response(:created)

      assert Map.delete(data, "id") == params
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      params = string_params_for(:tag) |> Map.put("value", "string")

      assert %{"errors" => _} =
               conn
               |> post(Routes.tag_path(conn, :create), %{"tag" => params})
               |> json_response(:unprocessable_entity)
    end
  end

  describe "PATCH /api/tags/:id" do
    @tag authentication: [role: "admin"]
    test "update tag", %{conn: conn} do
      %{id: id, value: value} = insert(:tag)

      update_params = %{
        "value" => Map.put(value, "expandable", "true")
      }

      assert %{"data" => data} =
               conn
               |> patch(Routes.tag_path(conn, :update, id), %{"tag" => update_params})
               |> json_response(:ok)

      assert %{"id" => ^id, "value" => %{"expandable" => "true"}} = data
    end
  end

  describe "DELETE /api/tags/:id" do
    @tag authentication: [role: "admin"]
    test "deletes chosen tag", %{conn: conn} do
      %{id: id} = insert(:tag)

      assert conn
             |> delete(Routes.tag_path(conn, :delete, id))
             |> response(:no_content)
    end
  end
end
