defmodule TdLm.Resources.Relation do
  @moduledoc """
  Module representing and entity relation in our database
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdLm.Resources
  alias TdLm.Resources.Tag

  schema "relations" do
    field(:source_id, :string)
    field(:source_type, :string)
    field(:target_id, :string)
    field(:target_type, :string)
    field(:context, :map, default: %{})

    many_to_many(:tags, Tag,
      join_through: "relations_tags",
      on_delete: :delete_all,
      on_replace: :delete
    )

    timestamps()
  end

  @doc false
  def create_changeset(relation, attrs) do
    attrs = attrs |> stringify_map()

    relation
    |> cast(attrs, [:source_id, :source_type, :target_id, :target_type, :context])
    |> validate_required([:source_id, :source_type, :target_id, :target_type, :context])
    |> put_assoc(:tags, parse_tag_ids(attrs))
  end

  @doc false
  def update_changeset(relation, attrs) do
    attrs = attrs |> stringify_map()

    relation
    |> cast(attrs, [:source_id, :source_type, :target_id, :target_type, :context])
    |> validate_required([:source_id, :source_type, :target_id, :target_type, :context])
    |> update_tags_assoc(attrs)
  end

  defp update_tags_assoc(changeset, attrs) do
    is_empty_tag_ids? = Map.get(attrs, "tag_ids", []) === []

    case changeset.valid? && not is_empty_tag_ids? do
      true ->
        changeset |> put_assoc(:tags, parse_tag_ids(attrs))

      false ->
        changeset
    end
  end

  defp parse_tag_ids(%{"tag_ids" => []}), do: []

  defp parse_tag_ids(%{"tag_ids" => tag_ids}) do
    tag_ids
    |> Enum.map(&Resources.get_tag(&1))
    |> Enum.filter(&(not is_nil(&1)))
  end

  defp parse_tag_ids(_), do: []

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
