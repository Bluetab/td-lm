defmodule TdLmWeb.RelationController do
  use TdHypermedia, :controller
  use TdLmWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdLm.Resources
  alias TdLm.Resources.Relation
  alias TdLmWeb.ErrorView
  alias TdLmWeb.SwaggerDefinitions

  action_fallback(TdLmWeb.FallbackController)

  @permission_attributes [:source_id, :source_type, :target_id, :target_type]

  def swagger_definitions do
    SwaggerDefinitions.relation_definitions()
  end

  swagger_path :index do
    get("/relations")
    description("Get a list of relations")
    produces("application/json")
    response(200, "OK", Schema.ref(:RelationsResponse))
    response(400, "Client Error")
  end

  def index(conn, params) do
    user = conn.assigns[:current_resource]

    relations =
      params
      |> Resources.list_relations()
      |> Enum.filter(fn rel ->
        params = stringify_map(rel)
        can?(user, show(params))
      end)

    render(
      conn,
      "index.json",
      hypermedia: collection_hypermedia("relation", conn, relations, params),
      relations: relations
    )
  end

  swagger_path :create do
    post("/relations")
    description("Adds a new relation between existing entities")
    produces("application/json")

    parameters do
      relation(:body, Schema.ref(:AddRelation), "Parameters used to create a relation")
    end

    response(200, "OK", Schema.ref(:RelationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def create(conn, %{"relation" => relation_params}) do
    user = conn.assigns[:current_resource]

    with true <- can?(user, create(relation_params)),
         {:ok, %Relation{} = relation} <- Resources.create_relation(relation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", relation_path(conn, :show, relation))
      |> render("show.json", relation: relation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  swagger_path :show do
    get("/relations/{id}")
    description("Get the relation of a provided id")
    produces("application/json")

    parameters do
      id(:path, :integer, "ID of the relation", required: true)
    end

    response(200, "OK", Schema.ref(:RelationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"id" => id} = params) do
    user = conn.assigns[:current_resource]

    with true <- can?(user, show(params)) do
      relation = Resources.get_relation!(id)
      render(conn, "show.json", relation: relation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  swagger_path :update do
    post("/relations/{id}")
    description("Updates the parameters of an existing relation")
    produces("application/json")

    parameters do
      id(:path, :integer, "ID of the relation", required: true)
      relation(:body, Schema.ref(:UpdateRelation), "Parameters used to create a relation")
    end

    response(200, "OK", Schema.ref(:RelationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def update(conn, %{"id" => id, "relation" => relation_params}) do
    user = conn.assigns[:current_resource]

    relation = Resources.get_relation!(id)
    params = stringify_map(Map.take(relation, @permission_attributes))

    with true <- can?(user, update(params)),
         {:ok, %Relation{} = relation} <- Resources.update_relation(relation, relation_params) do
      render(conn, "show.json", relation: relation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  swagger_path :delete do
    delete("/relations/{id}")
    description("Deletes a relation between entities")

    parameters do
      id(:path, :integer, "Relation ID", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns[:current_resource]

    relation = Resources.get_relation!(id)
    params = stringify_map(Map.take(relation, @permission_attributes))

    with true <- can?(user, delete(params)),
         {:ok, %Relation{}} <- Resources.delete_relation(relation) do
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  defp stringify_map(map) do
    Map.new(map, fn {key, value} -> {stringify_key(key), value} end)
  end

  defp stringify_key(key) do
    case is_atom(key) do
      true -> key
      false -> Atom.to_string(key)
    end
  end
end
