defmodule TdLmWeb.LinkController do
  require Logger
  import Canada, only: [can?: 2]
  use TdLmWeb, :controller
  use PhoenixSwagger
  alias TdLm.Audit
  alias TdLm.ResourceLinks
  alias TdLmWeb.ErrorView
  alias TdLmWeb.ResourceLinkView
  alias TdLmWeb.SwaggerDefinitions

  @events %{
    add_resource_link: "add_resource_link",
    delete_resource_link: "delete_resource_link"
  }

  def swagger_definitions do
    SwaggerDefinitions.link_definitions()
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

    response(200, "OK", Schema.ref(:ResourceLinkResponse))
    response(400, "Client Error")
  end

  def add_link(conn, %{"resource_type" => resource_type, "resource_id" => id, "field" => field}) do
    user = conn.assigns[:current_user]
    create_attrs = %{resource_id: id, resource_type: resource_type, field: field}

    with true <- can?(user, add_link(%{id: id, resource_type: resource_type})),
         {:ok, resource_link} <- ResourceLinks.create_resource_link(create_attrs) do
      audit = %{
        "audit" => %{
          "resource_id" => id,
          "resource_type" => resource_type,
          "payload" => create_attrs
        }
      }

      Audit.create_event(conn, audit, @events.add_resource_link)

      render(conn, ResourceLinkView, "resource_link.json", resource_link: resource_link)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      error ->
        Logger.error("While adding resource links... #{inspect(error)}")

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
      resource_id(:path, :string, "Resource Id", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceLinksResponse))
    response(400, "Client Error")
  end

  def get_links(conn, %{"resource_id" => id, "resource_type" => resource_type}) do
    user = conn.assigns[:current_user]

    with true <- can?(user, get_links(%{id: id, resource_type: resource_type})) do
      resource_links = ResourceLinks.list_resource_links(id, resource_type)

      render(conn, ResourceLinkView, "resource_links.json", resource_links: resource_links)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      error ->
        Logger.error("While getting resource links... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :get_link do
    get("/{resource_type}/{resource_id}/links/{field_id}")
    description("Get field of a given resource entity")
    produces("application/json")

    parameters do
      resource_type(:path, :string, "Resource Type", required: true)
      resource_id(:path, :string, "ID of the Resource", required: true)
      field_id(:path, :integer, "ID of the field", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceLinksResponse))
    response(400, "Client Error")
  end

  def get_link(conn, %{
        "resource_id" => id,
        "field_id" => field_id,
        "resource_type" => resource_type
      }) do
    user = conn.assigns[:current_user]

    with true <- can?(user, get_link(%{id: id, resource_type: resource_type})) do
      resource_link = ResourceLinks.get_resource_link!(field_id)
      render(conn, ResourceLinkView, "resource_link.json", resource_link: resource_link)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      error ->
        Logger.error("While getting resource link... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :delete_link do
    delete("/{resource_type}/{resource_id}/links/{field_id}")
    description("Deletes the link between a resource and a given field")
    produces("application/json")

    parameters do
      resource_type(:path, :string, "Resource Type", required: true)
      resource_id(:path, :string, "Resource ID", required: true)
      field_id(:path, :integer, "Field ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete_link(conn, %{
        "resource_type" => resource_type,
        "resource_id" => resource_id,
        "field_id" => field_id
      }) do
    user = conn.assigns[:current_user]
    resource_link = ResourceLinks.get_resource_link!(field_id)

    with true <- can?(user, delete_link(%{id: resource_id, resource_type: resource_type})) do
      ResourceLinks.delete_resource_link(resource_link)

      audit_payload =
        resource_link
        |> Map.drop([:__meta__])
        |> Map.from_struct()

      audit = %{
        "audit" => %{
          "resource_id" => resource_id,
          "resource_type" => resource_type,
          "payload" => audit_payload
        }
      }

      Audit.create_event(conn, audit, @events.delete_resource_link)
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      error ->
        Logger.error("While deleting resource link... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end
end
