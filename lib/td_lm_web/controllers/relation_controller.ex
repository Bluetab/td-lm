defmodule TdLmWeb.RelationController do
  require Logger
  use TdHypermedia, :controller
  use TdLmWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdLm.Audit
  alias TdLm.RelationLoader
  alias TdLm.Resources
  alias TdLm.Resources.Relation
  alias TdLmWeb.ErrorView
  alias TdLmWeb.SwaggerDefinitions

  action_fallback(TdLmWeb.FallbackController)

  @permission_attributes [:source_id, :source_type, :target_id, :target_type]
  @events %{
    add_relation: "add_relation",
    delete_relation: "delete_relation"
  }

  def swagger_definitions do
    SwaggerDefinitions.relation_definitions()
  end

  swagger_path :search do
    post("/relations/search")
    description("Search relations")
    parameters do
      search(
        :body,
        Schema.ref(:RelationFilterRequest),
        "Search query and filter parameters"
      )
    end
    produces("application/json")
    response(200, "OK", Schema.ref(:RelationsResponse))
    response(400, "Client Error")
  end

  def search(conn, params) do
    user = conn.assigns[:current_resource]

    relations =
      params
      |> Resources.list_relations()
      |> Enum.filter(fn rel ->
        rel_params = format_params_to_check_permissions(rel)
        can?(user, show(rel_params))
      end)

    params = params |> format_params_to_check_permissions()

    Logger.info("Permision params... #{inspect(params)}")
    Logger.info("Relations... #{inspect(relations)}")

    render(
      conn,
      "index.json",
      hypermedia: collection_hypermedia("relation", conn, relations, params),
      relations: relations
    )
  end

  swagger_path :index do
    get("/relations")
    description("Get a list of relations")
    produces("application/json")
    response(200, "OK", Schema.ref(:RelationsResponse))
    response(400, "Client Error")
  end

  def index(conn, _params) do
    user = conn.assigns[:current_resource]

    relations = Resources.list_relations()
      |> Enum.filter(fn rel ->
        rel_params = format_params_to_check_permissions(rel)
        can?(user, show(rel_params))
      end)

    render(
      conn,
      "index.json",
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
    params = relation_params |> format_params_to_check_permissions()

    with true <- can?(user, create(params)),
         {:ok, %Relation{} = relation} <- Resources.create_relation(relation_params) do
      Audit.create_event(
        conn,
        audit_create_attribures(relation_params, relation),
        @events.add_relation
      )

      RelationLoader.refresh(relation.id)

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
    params = params |> format_params_to_check_permissions()

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
    params = relation |> format_params_to_check_permissions()

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
    params = relation |> format_params_to_check_permissions()

    with true <- can?(user, delete(params)),
         {:ok, %Relation{}} <- Resources.delete_relation(relation) do
      Audit.create_event(conn, audit_delete_attribures(relation), @events.delete_relation)
      RelationLoader.delete(relation)

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

  defp audit_create_attribures(create_attributes, relation) do
    resource_id = create_attributes |> Map.get("source_id")
    resource_type = create_attributes |> Map.get("source_type")
    relation_types = fetch_relation_types(relation)

    payload = create_attributes |> Map.put("relation_types", relation_types)

    build_audit_map(resource_id, resource_type, payload)
  end

  defp audit_delete_attribures(relation) do
    resource_id = relation |> Map.get(:source_id)
    resource_type = relation |> Map.get(:source_type)
    relation_types = fetch_relation_types(relation)

    payload =
      relation
      |> Map.drop([:__meta__])
      |> Map.drop([:tags])
      |> Map.from_struct()
      |> Map.put("relation_types", relation_types)

    build_audit_map(resource_id, resource_type, payload)
  end

  defp build_audit_map(resource_id, resource_type, payload) do
    audit_map =
      Map.new()
      |> Map.put("resource_id", resource_id)
      |> Map.put("resource_type", resource_type)
      |> Map.put("payload", payload)

    Map.new() |> Map.put("audit", audit_map)
  end

  defp fetch_relation_types(relation) do
    relation
    |> Map.get(:tags)
    |> Enum.map(&Map.get(&1, :value))
    |> Enum.map(&Map.get(&1, "type"))
    |> Enum.filter(&(not is_nil(&1)))
  end

  defp format_params_to_check_permissions(%Relation{} = relation) do
    relation
    |> Map.take(@permission_attributes)
    |> stringify_map()
    |> format_params_to_check_permissions()
  end

  defp format_params_to_check_permissions(params_map) do
    resource_id = params_map |> Map.get("source_id")
    resource_type = params_map |> Map.get("source_type")

    Map.new()
    |> Map.put(:resource_id, resource_id)
    |> Map.put(:resource_type, resource_type)
  end

  defp stringify_map(map) do
    Map.new(map, fn {key, value} -> {stringify_key(key), value} end)
  end

  defp stringify_key(key) do
    case is_atom(key) do
      true -> Atom.to_string(key)
      false -> key
    end
  end
end
