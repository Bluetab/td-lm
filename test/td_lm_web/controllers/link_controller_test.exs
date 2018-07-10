defmodule TdLmWeb.LinkControllerTest do
  use TdLmWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
  import TdLmWeb.Authentication, only: :functions
  alias TdLmWeb.ApiServices.MockTdAuditService

  setup_all do
    start_supervised MockTdAuditService
    :ok
  end

  describe "create link" do
    test "renders link when data is valid", %{conn: _conn, swagger_schema: _schema} do
      assert true
    end

    test "renders errors when data is invalid", %{conn: _conn, swagger_schema: _schema} do
      assert true
    end
  end

end
