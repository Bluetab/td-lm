defmodule TdLmWeb.TagController do
  use TdLmWeb, :controller
  use PhoenixSwagger

  alias TdLm.Resources
  alias TdLm.Resources.Tag
  alias TdLmWeb.SwaggerDefinitions

  action_fallback(TdLmWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.tag_definitions()
  end

  swagger_path :index do
    get("/tags")
    description("Get a list of tags")
    produces("application/json")
    response(200, "OK", Schema.ref(:TagsResponse))
    response(400, "Client Error")
  end

  def index(conn, params) do
    tags = Resources.list_tags(params)
    render(conn, "index.json", tags: tags)
  end

  swagger_path :create do
    post("/tags")
    description("Creates a new tag")
    produces("application/json")

    parameters do
      tag(:body, Schema.ref(:CreateTag), "Parameters used to create a tag")
    end

    response(200, "OK", Schema.ref(:TagResponse))
    response(422, "Client Error")
  end

  def create(conn, %{"tag" => tag_params}) do
    with {:ok, %Tag{} = tag} <- Resources.create_tag(tag_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", tag_path(conn, :show, tag))
      |> render("show.json", tag: tag)
    end
  end

  swagger_path :show do
    get("/tags/{id}")
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

  swagger_path :update do
    post("/tags/{id}")
    description("Updates the parameters of an existing tag")
    produces("application/json")

    parameters do
      id(:path, :integer, "Tag ID", required: true)
      tag(:body, Schema.ref(:UpdateTag), "Parameters used to create a tag")
    end

    response(200, "OK", Schema.ref(:TagResponse))
    response(422, "Client Error")
  end

  def update(conn, %{"id" => id, "tag" => tag_params}) do
    tag = Resources.get_tag!(id)

    with {:ok, %Tag{} = tag} <- Resources.update_tag(tag, tag_params) do
      render(conn, "show.json", tag: tag)
    end
  end

  swagger_path :delete do
    delete("/tags/{id}")
    description("Deletes a tag given an id")

    parameters do
      id(:path, :integer, "Tag ID", required: true)
    end

    response(204, "No Content")
    response(422, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    tag = Resources.get_tag!(id)

    with {:ok, %Tag{}} <- Resources.delete_tag(tag) do
      send_resp(conn, :no_content, "")
    end
  end
end
