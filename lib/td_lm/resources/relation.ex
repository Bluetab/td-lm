defmodule TdLm.Resources.Relation do
  @moduledoc """
  Ecto Schema module for relations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdLm.Resources
  alias TdLm.Resources.Tag

  @valid_types ["business_concept", "data_field", "data_structure", "ingest"]

  schema "relations" do
    field(:source_id, :integer)
    field(:source_type, :string)
    field(:target_id, :integer)
    field(:target_type, :string)
    field(:context, :map, default: %{})
    field(:deleted_at, :utc_datetime_usec)

    many_to_many(:tags, Tag,
      join_through: "relations_tags",
      on_delete: :delete_all,
      on_replace: :delete
    )

    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = relation, %{} = params) do
    relation
    |> cast(params, [:source_id, :source_type, :target_id, :target_type, :context, :deleted_at])
    |> validate_required([:source_id, :source_type, :target_id, :target_type, :context])
    |> validate_inclusion(:source_type, @valid_types)
    |> validate_inclusion(:target_type, @valid_types)
    |> put_tags()
  end

  defp put_tags(%{valid?: true, params: %{"tag_ids" => tag_ids}} = changeset)
       when length(tag_ids) > 0 do
    tags = Resources.find_tags(id: {:in, tag_ids})
    put_assoc(changeset, :tags, tags)
  end

  defp put_tags(changeset), do: changeset
end
