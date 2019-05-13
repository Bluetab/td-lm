defmodule TdLmWeb.LinkController do
  require Logger
  use TdHypermedia, :controller
  import Canada, only: [can?: 2]
  use TdLmWeb, :controller
  use PhoenixSwagger
  alias TdLm.Audit
  alias TdLm.ResourceLinkLoader
  alias TdLm.ResourceLinks
  alias TdLmWeb.ErrorView
  alias TdLmWeb.ResourceLinkView
  alias TdLmWeb.SwaggerDefinitions

  @events %{
    add_resource_link: "add_resource_field",
    delete_resource_link: "delete_resource_field"
  }

  def swagger_definitions do
    SwaggerDefinitions.link_definitions()
  end

  swagger_path :add_link do
    description("Adds a new link between an existing entity and a new field")
    produces("application/json")

    parameters do
      field(:body, Schema.ref(:AddField), "Resource field")
      resource_type(:path, :string, "Resource Type", required: true)
      resource_id(:path, :string, "Resource ID", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceLinkResponse))
    response(400, "Client Error")
  end

  def add_link(conn, %{"resource_type" => resource_type, "resource_id" => id, "field" => field}) do
    user = conn.assigns[:current_resource]
    create_attrs = %{resource_id: id, resource_type: resource_type, field: field}

    with true <- can?(user, add_link(%{resource_id: id, resource_type: resource_type})),
         {:ok, resource_link} <- ResourceLinks.create_resource_link(create_attrs) do
      audit = %{
        "audit" => %{
          "resource_id" => id,
          "resource_type" => resource_type,
          "payload" => create_attrs
        }
      }

      Audit.create_event(conn, audit, @events.add_resource_link)
      ResourceLinkLoader.refresh(resource_link.id)

      conn
      |> put_view(ResourceLinkView)
      |> render("resource_link.json", resource_link: resource_link)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      error ->
        Logger.error("While adding resource links... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :get_links do
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
    user = conn.assigns[:current_resource]

    with true <- can?(user, get_links(%{resource_id: id, resource_type: resource_type})) do
      resource_links = ResourceLinks.list_resource_links(id, resource_type)
      link_resource = %{resource_type: resource_type, resource_id: id}

      conn
      |> put_view(ResourceLinkView)
      |> render("resource_links.json",
        # hypermedia: collection_hypermedia("link", conn, resource_links, ResourceLink),
        hypermedia: collection_hypermedia("link", conn, resource_links, link_resource),
        resource_links: resource_links
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      error ->
        Logger.error("While getting resource links... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :get_link do
    description("Get field of a given resource entity")
    produces("application/json")

    parameters do
      resource_type(:path, :string, "Resource Type", required: true)
      resource_id(:path, :string, "ID of the Resource", required: true)
      id(:path, :integer, "ID of the link", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceLinksResponse))
    response(400, "Client Error")
  end

  def get_link(conn, %{
        "resource_type" => resource_type,
        "resource_id" => resource_id,
        "id" => id
      }) do
    user = conn.assigns[:current_resource]

    with true <- can?(user, get_link(%{resource_id: resource_id, resource_type: resource_type})) do
      resource_link = ResourceLinks.get_resource_link!(id)

      conn
      |> put_view(ResourceLinkView)
      |> render("resource_link.json", resource_link: resource_link)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      error ->
        Logger.error("While getting resource link... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :index do
    description("Get all links")
    produces("application/json")

    response(200, "OK", Schema.ref(:ResourceLinksResponse))
    response(400, "Client Error")
  end

  def index(conn, _params) do
    user = conn.assigns[:current_resource]

    resource_links =
      ResourceLinks.list_links()
      |> Enum.reduce([], fn link, acc ->
        if can?(user, get_link(%{id: link.id, resource_type: link.resource_type})),
          do: acc ++ [link]
      end)

    conn
    |> put_view(ResourceLinkView)
    |> render("resource_links.json",
      resource_links: resource_links
    )
  end

  swagger_path :delete_link do
    description("Deletes the link between a resource and a given field")
    produces("application/json")

    parameters do
      resource_type(:path, :string, "Resource Type", required: true)
      resource_id(:path, :string, "Resource ID", required: true)
      field_id(:path, :integer, "Link ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete_link(conn, %{
        "resource_type" => resource_type,
        "resource_id" => resource_id,
        "id" => id
      }) do
    user = conn.assigns[:current_resource]
    resource_link = ResourceLinks.get_resource_link!(id)

    with true <-
           can?(user, delete_link(%{resource_id: resource_id, resource_type: resource_type})) do
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

      ResourceLinkLoader.delete(resource_link.field["field_id"], "field", %{
        resource_type: resource_type,
        resource_id: resource_id
      })

      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      error ->
        Logger.error("While deleting resource link... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end
end
