defmodule TdLmWeb.TagController do
  use TdLmWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdLm.Resources
  alias TdLm.Resources.Tag
  alias TdLmWeb.SwaggerDefinitions

  action_fallback(TdLmWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.tag_definitions()
  end

  swagger_path :index do
    description("Get a list of tags")
    produces("application/json")
    response(200, "OK", Schema.ref(:TagsResponse))
    response(400, "Client Error")
  end

  def index(conn, params) do
    tags = Resources.list_tags(params)
    render(conn, "index.json", tags: tags)
  end

  swagger_path :search do
    description("Search tags")
    produces("application/json")

    parameters do
      value(:body, Schema.ref(:TagSearch), "Parameters used to create search tags")
    end

    response(200, "OK", Schema.ref(:TagsResponse))
    response(400, "Client Error")
  end

  def search(conn, params) do
    tags = Resources.list_tags(params)
    render(conn, "index.json", tags: tags)
  end

  swagger_path :create do
    description("Creates a new tag")
    produces("application/json")

    parameters do
      tag(:body, Schema.ref(:CreateTag), "Parameters used to create a tag")
    end

    response(200, "OK", Schema.ref(:TagResponse))
    response(422, "Client Error")
    response(403, "Forbidden")
  end

  def create(conn, %{"tag" => tag_params}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, create_tag(%Tag{}))},
         {:ok, %{tag: tag}} <- Resources.create_tag(tag_params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.tag_path(conn, :show, tag))
      |> render("show.json", tag: tag)
    end
  end

  swagger_path :show do
    description("Get the tag of a provided id")
    produces("application/json")

    parameters do
      id(:path, :integer, "Tag ID", required: true)
    end

    response(200, "OK", Schema.ref(:TagResponse))
    response(422, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    tag = Resources.get_tag!(id)
    render(conn, "show.json", tag: tag)
  end

  swagger_path :delete do
    description("Deletes a tag given an id")

    parameters do
      id(:path, :integer, "Tag ID", required: true)
    end

    response(204, "No Content")
    response(422, "Client Error")
    response(403, "Forbidden")
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    tag = Resources.get_tag!(id)

    with {:can, true} <- {:can, can?(claims, delete_tag(tag))},
         {:ok, %{tag: _tag}} <- Resources.delete_tag(tag, claims) do
      send_resp(conn, :no_content, "")
    end
  end
end
