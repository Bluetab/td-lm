defmodule TdLmWeb.RelationController do
  require Logger
  use TdHypermedia, :controller
  use TdLmWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCache.ConceptCache
  alias TdLm.Cache.LinkLoader
  alias TdLm.Audit
  alias TdLm.Resources
  alias TdLm.Resources.Relation
  alias TdLmWeb.ErrorView
  alias TdLmWeb.SwaggerDefinitions

  action_fallback(TdLmWeb.FallbackController)

  @ingest_cache Application.get_env(:td_lm, :ingest_cache)

  @events %{
    add_relation: "add_relation",
    delete_relation: "delete_relation"
  }

  def swagger_definitions do
    SwaggerDefinitions.relation_definitions()
  end

  def search(conn, %{
        "resource_id" => resource_id,
        "resource_type" => resource_type,
        "related_to_type" => related_to_type
      }) do
    user = conn.assigns[:current_resource]

    relations =
      [
        %{
          "source_type" => resource_type,
          "source_id" => resource_id,
          "target_type" => related_to_type
        },
        %{
          "target_type" => resource_type,
          "target_id" => resource_id,
          "source_type" => related_to_type
        }
      ]
      |> Enum.flat_map(&Resources.list_relations/1)
      |> Enum.filter(&can?(user, show(&1)))
      |> Enum.map(&put_current_version_id(&1, "target", :target_id, related_to_type))
      |> Enum.map(&put_current_version_id(&1, "source", :source_id, related_to_type))

    render(
      conn,
      "index.json",
      hypermedia:
        collection_hypermedia("relation", conn, relations, %{
          resource_id: resource_id,
          resource_type: resource_type
        }),
      relations: relations
    )
  end

  swagger_path :search do
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
      |> Enum.filter(&can?(user, show(&1)))

    resource_key = %{
      resource_id: Map.get(params, "source_id"),
      resource_type: Map.get(params, "source_type")
    }

    render(
      conn,
      "index.json",
      hypermedia: collection_hypermedia("relation", conn, relations, resource_key),
      relations: relations
    )
  end

  swagger_path :index do
    description("Get a list of relations")
    produces("application/json")
    response(200, "OK", Schema.ref(:RelationsResponse))
    response(400, "Client Error")
  end

  def index(conn, _params) do
    user = conn.assigns[:current_resource]

    relations =
      Resources.list_relations()
      |> Enum.filter(&can?(user, show(&1)))

    render(
      conn,
      "index.json",
      relations: relations
    )
  end

  swagger_path :create do
    description("Adds a new relation between existing entities")
    produces("application/json")

    parameters do
      relation(:body, Schema.ref(:AddRelation), "Parameters used to create a relation")
    end

    response(200, "OK", Schema.ref(:RelationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def create(conn, %{
        "relation" => %{"source_id" => source_id, "source_type" => source_type} = relation_params
      }) do
    user = conn.assigns[:current_resource]

    with true <- can?(user, create(%{resource_id: source_id, resource_type: source_type})),
         {:ok, %Relation{} = relation} <- Resources.create_relation(relation_params) do
      Audit.create_event(
        conn,
        audit_create_attributes(relation_params, relation),
        @events.add_relation
      )

      LinkLoader.refresh(relation.id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.relation_path(conn, :show, relation))
      |> render("show.json", relation: relation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :show do
    description("Get the relation of a provided id")
    produces("application/json")

    parameters do
      id(:path, :integer, "ID of the relation", required: true)
    end

    response(200, "OK", Schema.ref(:RelationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns[:current_resource]
    relation = Resources.get_relation!(id)

    with true <- can?(user, show(relation)) do
      render(conn, "show.json", relation: relation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :update do
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

    with true <- can?(user, update(relation)),
         {:ok, %Relation{} = relation} <- Resources.update_relation(relation, relation_params) do
      render(conn, "show.json", relation: relation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :delete do
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

    with true <- can?(user, delete(relation)),
         {:ok, %Relation{}} <- Resources.delete_relation(relation) do
      Audit.create_event(conn, audit_delete_attributes(relation), @events.delete_relation)
      LinkLoader.delete(relation.id)

      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp audit_create_attributes(create_attributes, relation) do
    resource_id = create_attributes |> Map.get("source_id")
    resource_type = create_attributes |> Map.get("source_type")
    relation_types = fetch_relation_types(relation)

    payload = create_attributes |> Map.put("relation_types", relation_types)

    build_audit_map(resource_id, resource_type, payload)
  end

  defp audit_delete_attributes(relation) do
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

  defp put_current_version_id(relation, relation_side, relation_id_key, target_type) do
    relation_side_attrs =
      relation
      |> Map.get(:context)
      |> Map.get(relation_side)

    case relation_side_attrs do
      nil ->
        relation

      relation_side_attrs ->
        version_id = get_version_id(target_type, Map.get(relation, relation_id_key))
        put_version_id_in_context(relation, relation_side, relation_side_attrs, version_id)
    end
  end

  defp put_version_id_in_context(relation, _relation_side, _relation_side_attrs, nil) do
    relation
  end

  defp put_version_id_in_context(relation, relation_side, relation_side_attrs, version_id) do
    side_map = Map.put(relation_side_attrs, "version_id", version_id)
    context = Map.put(relation.context, relation_side, side_map)
    Map.put(relation, :context, context)
  end

  defp get_version_id("business_concept", entity_id) do
    {:ok, id} = ConceptCache.get(entity_id, :business_concept_version_id)
    id
  end

  defp get_version_id("ingest", entity_id) do
    @ingest_cache.get_ingest_version_id(entity_id)
  end

  defp get_version_id(_, _) do
  end
end
