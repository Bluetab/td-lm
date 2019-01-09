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
    dynamic = filter(params, fields)

    Repo.all(from p in Relation,
      where: ^dynamic
    )
  end

  def filter(params, fields) do
    dynamic = true
    Enum.reduce(Map.keys(params), dynamic, fn (key, acc) ->
       key_as_atom = if is_binary(key), do: String.to_atom(key), else: key
       case Enum.member?(fields, key_as_atom) do
         true ->  dynamic([p], field(p, ^key_as_atom) == ^params[key] and ^acc)
         false -> acc
       end
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
  def get_relation!(id), do: Repo.get!(Relation, id)

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
    |> Relation.changeset(attrs)
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
    |> Relation.changeset(attrs)
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
    Relation.changeset(relation, %{})
  end
end
