defmodule TdLmWeb.LinkController do
  require Logger
  import Canada, only: [can?: 2]
  use TdLmWeb, :controller
  use PhoenixSwagger
  alias TdLm.Audit
  alias TdLm.ResourceFields
  alias TdLmWeb.ErrorView
  alias TdLmWeb.ResourceFieldView
  alias TdLmWeb.SwaggerDefinitions

  @events %{
    add_resource_field: "add_resource_field",
    delete_resource_field: "delete_resource_field"
  }

  def swagger_definitions do
    SwaggerDefinitions.field_definitions()
  end

  swagger_path :add_link do
    post("/{resource_type}/{resource_id}/links")
    description("Adds a new link between an existing entity and a new field")
    produces("application/json")

    parameters do
      field(:body, Schema.ref(:AddField), "Resource field")
      resource_type(:path, :string, "Resource Type", required: true)
      id(:path, :string, "Resource ID", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceFieldResponse))
    response(400, "Client Error")
  end

  def add_link(conn, %{"resource_type" => resource_type, "resource_id" => id, "field" => field}) do

    user = conn.assigns[:current_user]
    create_attrs = %{resource_id: id, resource_type: resource_type, field: field}

    with true <- can?(user, add_link(%{id: id, resource_type: resource_type})),
     {:ok, resource_field} <- ResourceFields.create_resource_field(create_attrs) do

      audit = %{
        "audit" => %{
          "resource_id" => id,
          "resource_type" => resource_type,
          "payload" => create_attrs
        }
      }

      Audit.create_event(conn, audit, @events.add_resource_field)

      render(conn, ResourceFieldView, "resource_field.json", resource_field: resource_field)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      error ->
        Logger.error("While adding  resource fields... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  swagger_path :get_links do
    get("/{resource_type}/{resource_id}/links")
    description("Get resource data fields")
    produces("application/json")

    parameters do
      resource_type(:path, :string, "Resource Type", required: true)
      id(:path, :string, "Resource Id", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceFieldsResponse))
    response(400, "Client Error")
  end

  def get_links(conn, %{"resource_id" => id, "resource_type" => resource_type}) do
    user = conn.assigns[:current_user]

    with true <- can?(user, get_links(%{id: id, resource_type: resource_type})) do
      resource_fields =
        ResourceFields.list_resource_fields(id, resource_type)

      render(conn, ResourceFieldView, "resource_fields.json", resource_fields: resource_fields)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      error ->
        Logger.error("While getting resource fields... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end
end
