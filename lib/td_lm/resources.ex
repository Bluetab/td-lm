defmodule TdLm.Resources do
  @moduledoc """
  The Resources context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdLm.Audit
  alias TdLm.Auth.Claims
  alias TdLm.Cache.LinkLoader
  alias TdLm.Graph.Data
  alias TdLm.Repo
  alias TdLm.Resources.Relation
  alias TdLm.Resources.Tag

  def list_relations(params \\ %{}) do
    params
    |> Enum.reduce(Relation, fn
      {"id", id}, q -> where(q, [r], r.id == ^id)
      {"limit", limit}, q -> limit(q, ^limit)
      {"min_id", min_id}, q -> where(q, [r], r.id >= ^min_id)
      {"since", since}, q -> where(q, [r], r.updated_at >= ^since)
      {"source_id", id}, q -> where(q, [r], r.source_id == ^id)
      {"source_type", t}, q -> where(q, [r], r.source_type == ^t)
      {"target_id", id}, q -> where(q, [r], r.target_id == ^id)
      {"target_type", t}, q -> where(q, [r], r.target_type == ^t)
      {"value", %{} = value}, q -> where_relation_value(q, value)
    end)
    |> order_by([:updated_at, :id])
    |> preload(:tags)
    |> Repo.all()
  end

  defp where_relation_value(q, %{} = value) do
    q = join(q, :left, [r], _ in assoc(r, :tags))

    Enum.reduce(value, q, fn {k, v}, q ->
      where(q, [_, rt], rt.value[^k] in ^List.wrap(v))
    end)
  end

  @spec count_relations_by_source(any, any) :: map
  def count_relations_by_source(source_type, target_type) do
    Relation
    |> Repo.all()
    |> Enum.group_by(& &1.source_id)
    |> Enum.map(fn {key, value} ->
      {key, count_valid_relations(value, source_type, target_type)}
    end)
    |> Map.new()
  end

  defp count_valid_relations(value, source_type, target_type) do
    Enum.count(value, fn r ->
      r.source_type == source_type and r.target_type == target_type
    end)
  end

  @doc """
  Gets a single relation.   Raises `Ecto.NoResultsError` if the Relation does not exist.
  """
  def get_relation!(id) do
    Relation
    |> Repo.get!(id)
    |> Repo.preload(:tags)
  end

  def get_relation(id), do: Repo.get(Relation, id)

  @doc """
  Creates a relation and publishes an audit event.
  """
  def create_relation(%{} = params, %Claims{user_id: user_id}) do
    changeset = Relation.changeset(params)

    Multi.new()
    |> Multi.insert(:relation, changeset)
    |> Multi.run(:audit, Audit, :relation_created, [changeset, user_id])
    |> Repo.transaction()
    |> on_create()
  end

  defp on_create(res) do
    with {:ok, %{relation: %{id: id}}} <- res do
      LinkLoader.refresh(id)
      res
    end
  end

  @doc """
  Deletes a relation and publishes an audit event.
  """
  def delete_relation(%Relation{} = relation, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.delete(:relation, relation)
    |> Multi.run(:audit, Audit, :relation_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete_relation()
  end

  defp on_delete_relation(res) do
    with {:ok, %{relation: %{id: id}}} <- res do
      LinkLoader.delete(id)
      res
    end
  end

  @doc """
  Returns the list of tags.
  """
  def list_tags(params \\ %{}) do
    params
    |> Enum.reduce(Tag, fn
      {"value", %{} = value}, q -> where_tag_value(q, value)
    end)
    |> Repo.all()
  end

  defp where_tag_value(q, %{} = value) do
    Enum.reduce(value, q, fn {k, v}, q ->
      where(q, [t], t.value[^k] in ^List.wrap(v))
    end)
  end

  @doc """
  Gets a single tag.

  Raises `Ecto.NoResultsError` if the Tag does not exist.
  """
  def get_tag!(id) do
    Tag
    |> Repo.get!(id)
    |> Repo.preload(:relations)
  end

  @doc """
  Gets a single tag.

  Returns nil if the Tag does not exist.
  """
  def get_tag(id), do: Repo.get(Tag, id)

  @doc """
  Creates a tag and publishes and audit event.
  """
  def create_tag(%{} = params, %Claims{user_id: user_id}) do
    changeset = Tag.changeset(params)

    Multi.new()
    |> Multi.insert(:tag, changeset)
    |> Multi.run(:audit, Audit, :tag_created, [user_id])
    |> Repo.transaction()
  end

  @doc """
  Deletes a tag and publishes an audit event.
  """
  def delete_tag(%Tag{id: id} = tag, %Claims{user_id: user_id}) do
    relation_id_query =
      Relation
      |> join(:inner, [r], t in assoc(r, :tags))
      |> where([_r, t], t.id == ^id)
      |> select([r], r.id)

    Multi.new()
    |> Multi.update_all(:relations, relation_id_query, set: [updated_at: DateTime.utc_now()])
    |> Multi.delete(:tag, tag)
    |> Multi.run(:audit, Audit, :tag_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete_tag()
  end

  defp on_delete_tag(res) do
    with {:ok, %{relations: {count, ids}}} = res when count > 0 <- res do
      LinkLoader.refresh(ids)
      res
    end
  end

  @spec list_stale_relations(String.t(), list(integer)) :: list(Relation.t())
  def list_stale_relations(resource_type, active_ids) do
    Relation
    |> where([r], r.source_type == ^resource_type and r.source_id not in ^active_ids)
    |> or_where([r], r.target_type == ^resource_type and r.target_id not in ^active_ids)
    |> Repo.all()
  end

  @spec deprecate(String.t(), list(integer)) ::
          :ok | {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any}}
  def deprecate(resource_type, [_ | _] = resource_ids) do
    ts = DateTime.utc_now()

    query =
      Relation
      |> where([r], r.source_type == ^resource_type and r.source_id in ^resource_ids)
      |> or_where([r], r.target_type == ^resource_type and r.target_id in ^resource_ids)
      |> where([r], is_nil(r.deleted_at))
      |> select([r], r)

    Multi.new()
    |> Multi.update_all(:deprecated, query, set: [deleted_at: ts])
    |> Multi.run(:audit, Audit, :relations_deprecated, [])
    |> Repo.transaction()
  end

  def deprecate(_resource_type, []), do: {:ok, %{deprecated: {0, []}}}

  @spec activate(String.t(), list(integer)) :: :ok | {:ok, map}
  def activate(resource_type, [_ | _] = resource_ids) do
    reply =
      Relation
      |> where([r], r.source_type == ^resource_type and r.source_id in ^resource_ids)
      |> or_where([r], r.target_type == ^resource_type and r.target_id in ^resource_ids)
      |> where([r], not is_nil(r.deleted_at))
      |> select([r], r)
      |> Repo.update_all(set: [deleted_at: nil])

    {:ok, %{activated: reply}}
  end

  def activate(_resource_type, []), do: {:ok, %{activated: {0, []}}}

  def find_tags(clauses) do
    clauses
    |> Enum.reduce(Tag, fn
      {:id, {:in, ids}}, q -> where(q, [t], t.id in ^ids)
    end)
    |> Repo.all()
  end

  def graph(claims, id, resource_type, opts \\ []) do
    id = Data.id(resource_type, id)

    g = Data.graph()

    case Graph.has_vertex?(g, id) do
      true ->
        all =
          g
          |> Data.all([id])
          |> Enum.map(&Graph.vertex(g, &1))
          |> Enum.reject(&reject_by_type(&1, opts[:types]))
          # credo:disable-for-next-line
          |> Enum.reject(&reject_by_permissions(&1, claims))
          |> Enum.uniq_by(&Map.get(&1, :id))

        ids = Enum.map(all, &Map.get(&1, :id))
        subgraph = Graph.subgraph(g, ids)
        %{nodes: nodes(all), edges: edges(subgraph)}

      _ ->
        %{nodes: [], edges: []}
    end
  end

  defp reject_by_type(%{label: %{resource_type: type}}, [_ | _] = types) do
    type not in types
  end

  defp reject_by_type(_vertex, _types), do: false

  defp reject_by_permissions(%{label: label}, claims) do
    import Canada, only: [can?: 2]
    not can?(claims, show(Map.take(label, [:resource_id, :resource_type])))
  end

  defp nodes(nodes) do
    nodes
    |> Enum.map(&Map.take(&1, [:id, :label]))
    |> Enum.map(fn %{id: id, label: label} ->
      Map.new()
      |> Map.put(:id, id)
      |> Map.merge(Map.take(label, [:resource_id, :resource_type]))
    end)
  end

  defp edges(graph) do
    graph
    |> Graph.get_edges()
    |> Enum.map(fn %{id: id, label: label, v1: v1, v2: v2} ->
      tags = Map.get(label, :tags)

      Map.new()
      |> Map.put(:id, id)
      |> Map.put(:source_id, v1)
      |> Map.put(:target_id, v2)
      |> Map.put(:tags, tags)
    end)
  end
end
