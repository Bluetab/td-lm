defmodule TdLmWeb.RelationController do
  use TdHypermedia, :controller
  use TdLmWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCache.ConceptCache
  alias TdCache.IngestCache
  alias TdLm.Resources

  require Logger

  action_fallback(TdLmWeb.FallbackController)

  def search(
        conn,
        %{
          "resource_id" => resource_id,
          "resource_type" => resource_type,
          "related_to_type" => related_to_type
        } = params
      ) do
    claims = conn.assigns[:current_resource]
    lang = conn.assigns[:locale]
    status = Map.get(params, "status", "approved")

    relations =
      [
        %{
          "source_type" => resource_type,
          "source_id" => resource_id,
          "target_type" => related_to_type,
          "status" => status
        },
        %{
          "target_type" => resource_type,
          "target_id" => resource_id,
          "source_type" => related_to_type,
          "status" => status
        }
      ]
      |> Enum.flat_map(&Resources.list_relations/1)
      |> Enum.filter(&can?(claims, show(&1)))
      |> Enum.map(&maybe_add_tags/1)
      |> Enum.map(&refresh_attributes(&1, "target", :target_id, related_to_type, lang: lang))
      |> Enum.map(&refresh_attributes(&1, "source", :source_id, related_to_type, lang: lang))

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

  def search(conn, params) do
    claims = conn.assigns[:current_resource]

    relations =
      params
      |> Map.put_new("status", "approved")
      |> Resources.list_relations()
      |> Enum.map(&maybe_add_tags/1)
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

  def index(conn, params) do
    claims = conn.assigns[:current_resource]
    status = Map.get(params, "status", "approved")

    relations =
      %{"status" => status}
      |> Resources.list_relations()
      |> Enum.filter(&can?(claims, show(&1)))
      |> Enum.map(&maybe_add_tags/1)

    render(conn, "index.json", relations: relations)
  end

  def create(conn, %{"relation" => params}) do
    claims = conn.assigns[:current_resource]

    updated_relation_params = add_tag_id(params)

    with {:params, %{"source_id" => source_id, "source_type" => source_type}} <-
           {:params, updated_relation_params},
         {:can, true} <-
           {:can, can?(claims, create(%{resource_id: source_id, resource_type: source_type}))},
         {:ok, %{relation: relation}} <-
           Resources.create_relation(updated_relation_params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.relation_path(conn, :show, relation))
      |> render("show.json", relation: relation)
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    relation =
      id
      |> Resources.get_relation!()
      |> maybe_add_tags()

    with {:can, true} <- {:can, can?(claims, show(relation))} do
      render(conn, "show.json", relation: relation)
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    relation = Resources.get_relation!(id)

    with {:can, true} <- {:can, can?(claims, delete(relation))},
         {:ok, _} <- Resources.delete_relation(relation, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  defp refresh_attributes(relation, relation_side, relation_id_key, target_type, opts)
       when target_type in ["business_concept", "ingest"] do
    relation_side_attrs =
      relation
      |> Map.get(:context)
      |> Map.get(relation_side)

    case relation_side_attrs do
      nil ->
        relation

      relation_side_attrs ->
        cached = fetch_attributes(Map.get(relation, relation_id_key), target_type, opts)
        version_id = Map.get(cached, :version_id)
        name = Map.get(cached, :name)

        relation_side_attrs =
          relation_side_attrs
          |> Map.put("name", name)
          |> Map.put("version_id", version_id)

        context = Map.put(relation.context, relation_side, relation_side_attrs)
        Map.put(relation, :context, context)
    end
  end

  defp refresh_attributes(relation, _, _, _, _), do: relation

  defp fetch_attributes(entity_id, "business_concept", opts) do
    case ConceptCache.get(entity_id, opts) do
      {:ok, concept = %{}} ->
        concept
        |> Map.take([:name, :business_concept_version_id])
        |> Enum.map(fn
          {:business_concept_version_id, version} -> {:version_id, version}
          other -> other
        end)
        |> Enum.into(%{})

      _ ->
        %{}
    end
  end

  defp fetch_attributes(entity_id, "ingest", _opts) do
    case IngestCache.get(entity_id) do
      {:ok, ingest = %{}} ->
        ingest
        |> Map.take([:name, :ingest_version_id])
        |> Enum.map(fn
          {:ingest_version_id, version} -> {:version_id, version}
          other -> other
        end)
        |> Enum.into(%{})

      _ ->
        %{}
    end
  end

  defp fetch_attributes(_entity_id, _target_type, _opts), do: %{}

  defp maybe_add_tags(%{tag: nil} = relation), do: relation

  defp maybe_add_tags(%{tag: tag} = relation),
    do: Map.put(relation, :tags, [%{id: tag.id, value: tag.value}])

  defp add_tag_id(%{"tag_ids" => []} = params), do: Map.put(params, "tag_id", nil)
  defp add_tag_id(%{"tag_ids" => [tag_id]} = params), do: Map.put(params, "tag_id", tag_id)
  defp add_tag_id(params), do: params
end
