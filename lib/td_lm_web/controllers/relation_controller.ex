defmodule TdLmWeb.RelationController do
  use TdHypermedia, :controller
  use TdLmWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCache.ConceptCache
  alias TdCache.IngestCache
  alias TdLm.Resources
  alias TdLmWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdLmWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.relation_definitions()
  end

  def search(conn, %{
        "resource_id" => resource_id,
        "resource_type" => resource_type,
        "related_to_type" => related_to_type
      }) do
    claims = conn.assigns[:current_resource]

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
      |> Enum.filter(&can?(claims, show(&1)))
      |> Enum.map(&refresh_attributes(&1, "target", :target_id, related_to_type))
      |> Enum.map(&refresh_attributes(&1, "source", :source_id, related_to_type))

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
    claims = conn.assigns[:current_resource]

    relations =
      params
      |> Resources.list_relations()
      |> Enum.filter(&can?(claims, show(&1)))

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
    claims = conn.assigns[:current_resource]

    relations =
      Resources.list_relations()
      |> Enum.filter(&can?(claims, show(&1)))

    render(conn, "index.json", relations: relations)
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

  def create(conn, %{"relation" => relation_params}) do
    claims = conn.assigns[:current_resource]

    with {:params, %{"source_id" => source_id, "source_type" => source_type}} <-
           {:params, relation_params},
         {:can, true} <-
           {:can, can?(claims, create(%{resource_id: source_id, resource_type: source_type}))},
         {:ok, %{relation: relation}} <- Resources.create_relation(relation_params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.relation_path(conn, :show, relation))
      |> render("show.json", relation: relation)
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
    claims = conn.assigns[:current_resource]
    relation = Resources.get_relation!(id)

    with {:can, true} <- {:can, can?(claims, show(relation))} do
      render(conn, "show.json", relation: relation)
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
    claims = conn.assigns[:current_resource]
    relation = Resources.get_relation!(id)

    with {:can, true} <- {:can, can?(claims, delete(relation))},
         {:ok, _} <- Resources.delete_relation(relation, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  defp refresh_attributes(relation, relation_side, relation_id_key, target_type) do
    relation_side_attrs =
      relation
      |> Map.get(:context)
      |> Map.get(relation_side)

    case relation_side_attrs do
      nil ->
        relation

      relation_side_attrs ->
        version_id = get_version_id(target_type, Map.get(relation, relation_id_key))
        name = get_name(target_type, Map.get(relation, relation_id_key))

        relation_side_attrs =
          relation_side_attrs
          |> Map.put("version_id", version_id)
          |> Map.put("name", name)

        put_attrs_in_context(relation, relation_side, relation_side_attrs, version_id)
    end
  end

  defp put_attrs_in_context(relation, _relation_side, _relation_side_attrs, nil) do
    relation
  end

  defp put_attrs_in_context(relation, relation_side, relation_side_attrs, _version_id) do
    context = Map.put(relation.context, relation_side, relation_side_attrs)
    Map.put(relation, :context, context)
  end

  defp get_version_id("business_concept", entity_id) do
    {:ok, id} = ConceptCache.get(entity_id, :business_concept_version_id)
    id
  end

  defp get_version_id("ingest", entity_id) do
    IngestCache.get_ingest_version_id(entity_id)
  end

  defp get_version_id(_, _) do
  end

  defp get_name("business_concept", entity_id) do
    {:ok, name} = ConceptCache.get(entity_id, :name)
    name
  end

  defp get_name(_, _) do
  end
end
