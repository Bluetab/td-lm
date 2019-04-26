defmodule TdLm.Resources do
  @moduledoc """
  The Resources context.
  """

  import Ecto.Query, warn: false
  alias TdLm.Repo

  alias TdLm.Resources.Relation

  @doc """
  Returns the list of relations.

  ## Examples

      iex> list_relations()
      [%Relation{}, ...]

  """
  def list_relations(params \\ %{}) do
    fields = Relation.__schema__(:fields)
    dynamic = and_filter(params, fields, true)

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
    |> Enum.group_by(&(&1.source_id))
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
  Creates a relation.

  ## Examples

      iex> create_relation(%{field: value})
      {:ok, %Relation{}}

      iex> create_relation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_relation(attrs \\ %{}) do
    %Relation{}
    |> Relation.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a relation.

  ## Examples

      iex> update_relation(relation, %{field: new_value})
      {:ok, %Relation{}}

      iex> update_relation(relation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_relation(%Relation{} = relation, attrs) do
    relation
    |> Relation.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Relation.

  ## Examples

      iex> delete_relation(relation)
      {:ok, %Relation{}}

      iex> delete_relation(relation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_relation(%Relation{} = relation) do
    Repo.delete(relation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking relation changes.

  ## Examples

      iex> change_relation(relation)
      %Ecto.Changeset{source: %Relation{}}

  """
  def change_relation(%Relation{} = relation) do
    Relation.create_changeset(relation, %{})
  end

  alias TdLm.Resources.Tag

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
  Creates a tag.

  ## Examples

      iex> create_tag(%{field: value})
      {:ok, %Tag{}}

      iex> create_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.

  ## Examples

      iex> update_tag(tag, %{field: new_value})
      {:ok, %Tag{}}

      iex> update_tag(tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Tag.

  ## Examples

      iex> delete_tag(tag)
      {:ok, %Tag{}}

      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.

  ## Examples

      iex> change_tag(tag)
      %Ecto.Changeset{source: %Tag{}}

  """
  def change_tag(%Tag{} = tag) do
    Tag.changeset(tag, %{})
  end

  defp filter_tags(params, fields) do
    conditions =
      case Map.has_key?(params, "value") && Enum.member?(fields, :value) do
        true ->
          build_filter_for_value(:value, params)

        false ->
          true
      end

    and_params = Map.drop(params, ["value"])
    and_filter(and_params, fields, conditions)
  end

  defp and_filter(params, fields, conditions) do
    Enum.reduce(Map.keys(params), conditions, fn key, acc ->
      key_as_atom = if is_binary(key), do: String.to_atom(key), else: key

      case Enum.member?(fields, key_as_atom) do
        true -> filter_by_type(key_as_atom, params[key], acc)
        false -> acc
      end
    end)
  end

  defp build_filter_for_value(value_key_as_atom, params) do
    value_field = params |> Map.get("value") |> Map.get("type")
    filter_tag_by_type(:tag, value_key_as_atom, value_field)
  end

  defp filter_tag_by_type(:tag, :value = atom_key, value_field) when is_list(value_field) do
    Enum.reduce(value_field, nil, fn value, acc ->
      param_value = Map.new() |> Map.put("type", value)
      filter_value_in_tag(atom_key, param_value, acc)
    end)
  end

  defp filter_tag_by_type(:tag, :value = atom_key, value_field) do
    param_value = Map.new() |> Map.put("type", value_field)
    dynamic([p, _], fragment("(?) @> ?::jsonb", field(p, ^atom_key), ^param_value))
  end

  def filter_value_in_tag(atom_key, param_value, acc) when is_nil(acc) do
    dynamic([p, _], fragment("(?) @> ?::jsonb", field(p, ^atom_key), ^param_value))
  end

  def filter_value_in_tag(atom_key, param_value, acc) do
    dynamic([p, _], fragment("(?) @> ?::jsonb", field(p, ^atom_key), ^param_value) or ^acc)
  end

  defp filter_by_type(atom_key, param_value, acc) when is_map(param_value) do
    dynamic([p, _], fragment("(?) @> ?::jsonb", field(p, ^atom_key), ^param_value) and ^acc)
  end

  defp filter_by_type(atom_key, param_value, acc) do
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
end
