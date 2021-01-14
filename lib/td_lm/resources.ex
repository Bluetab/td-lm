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

  @doc """
  Returns the list of relations.

  ## Examples

      iex> list_relations()
      [%Relation{}, ...]

  """
  def list_relations(params \\ %{}) do
    fields = Relation.__schema__(:fields)
    dynamic = and_filter(params, fields)

    Relation
    |> preload([:tags])
    |> join(:left, [p], _ in assoc(p, :tags))
    |> where(^dynamic)
    |> include_where_for_external_params(params)
    |> Repo.all()
  end

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
  Gets a single relation.

  Raises `Ecto.NoResultsError` if the Relation does not exist.

  ## Examples

      iex> get_relation!(123)
      %Relation{}

      iex> get_relation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_relation!(id) do
    Relation
    |> Repo.get!(id)
    |> Repo.preload(:tags)
  end

  @doc """
  Gets a single relation.

  Returns nil if the Relation does not exist.

  ## Examples

      iex> get_relation(123)
      %Relation{}

      iex> get_relation(456)
      ** nil

  """
  def get_relation(id), do: Repo.get(Relation, id)

  @doc """
  Creates a relation and publishes an audit event.

  ## Examples

      iex> create_relation(%{field: value}, claims)
      {:ok, %{audit: "event_id", relation: %Relation{}}}

      iex> create_relation(%{field: bad_value}, claims)
      {:error, :relation, %Ecto.Changeset{}, %{}}

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

  ## Examples

      iex> delete_relation(relation, claims)
      {:ok, %{audit: "event_id", relation: %Relation{}}}

      iex> delete_relation(relation, claims)
      {:error, :relation, %Ecto.Changeset{}, %{}}

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

  ## Examples

      iex> list_tags()
      [%Tag{}, ...]

  """
  def list_tags(params \\ %{}) do
    fields = Tag.__schema__(:fields)
    dynamic = filter_tags(params, fields)

    Repo.all(
      from(
        p in Tag,
        where: ^dynamic
      )
    )
  end

  @doc """
  Gets a single tag.

  Raises `Ecto.NoResultsError` if the Tag does not exist.

  ## Examples

      iex> get_tag!(123)
      %Tag{}

      iex> get_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag!(id) do
    Tag
    |> Repo.get!(id)
    |> Repo.preload(:relations)
  end

  @doc """
  Gets a single tag.

  Returns nil if the Tag does not exist.

  ## Examples

      iex> get_tag(123)
      %Tag{}

      iex> get_tag(456)
      ** nil

  """
  def get_tag(id), do: Repo.get(Tag, id)

  @doc """
  Creates a tag and publishes and audit event.

  ## Examples

      iex> create_tag(%{field: value}, claims)
      {:ok, %{audit: "event_id", tag: %Tag{}}}

      iex> create_tag(%{field: bad_value}, claims)
      {:error, :tag, %Ecto.Changeset{}, %{}}

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

  ## Examples

      iex> delete_tag(tag, claims)
      {:ok, %{relations: {0, []}, tag: %Tag{}, audit: "event_id"}

      iex> delete_tag(tag, claims)
      {:error, :tag, %Ecto.Changeset{}, %{}}

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

  defp filter_tags(params, fields) do
    and_filter(params, fields)
  end

  defp and_filter(params, fields) do
    dynamic = true

    Enum.reduce(Map.keys(params), dynamic, fn key, acc ->
      key_as_atom = if is_binary(key), do: String.to_atom(key), else: key

      case Enum.member?(fields, key_as_atom) do
        true ->
          filter_by_field(key_as_atom, params[key], acc)

        false ->
          acc
      end
    end)
  end

  defp filter_by_field(atom_key, param_value, acc) when is_map(param_value) do
    dynamic([p, _], fragment("(?) @> ?::jsonb", field(p, ^atom_key), ^param_value) and ^acc)
  end

  defp filter_by_field(atom_key, param_value, acc) do
    dynamic([p, _], field(p, ^atom_key) == ^param_value and ^acc)
  end

  defp include_where_for_external_params(query, %{"value" => value}) do
    dynamic = false

    values_type = value |> Map.get("type")

    case is_list(values_type) do
      true ->
        condition =
          Enum.reduce(values_type, dynamic, fn el, acc ->
            param_value = Map.new() |> Map.put("type", el)
            dynamic([_, t], fragment("(?) @> ?::jsonb", field(t, :value), ^param_value) or ^acc)
          end)

        query |> where(^condition)

      false ->
        query |> where([_, t], fragment("(?) @> ?::jsonb", field(t, :value), ^value))
    end
  end

  defp include_where_for_external_params(query, _), do: query

  def list_stale_relations(resource_type, active_ids) do
    Relation
    |> where([r], r.source_type == ^resource_type and r.source_id not in ^active_ids)
    |> or_where([r], r.target_type == ^resource_type and r.target_id not in ^active_ids)
    |> Repo.all()
  end

  @spec deprecate(String.t(), list(String.t())) ::
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

  @spec activate(String.t(), list(String.t())) ::
          :ok | {:ok, map}
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
