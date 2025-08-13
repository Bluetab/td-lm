defmodule TdLm.Resources.Relation do
  @moduledoc """
  Ecto Schema module for relations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdLm.Resources.Tag

  @valid_types [
    "business_concept",
    "data_field",
    "data_structure",
    "ingest",
    "implementation_ref"
  ]

  schema "relations" do
    field(:source_id, :integer)
    field(:source_type, :string)
    field(:target_id, :integer)
    field(:target_type, :string)
    field(:context, :map, default: %{})
    field(:origin, :string, default: nil)
    field(:deleted_at, :utc_datetime_usec)
    field(:tags, {:array, :map}, virtual: true, default: [])
    belongs_to(:tag, Tag)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = relation, %{} = params) do
    relation
    |> cast(params, [
      :source_id,
      :source_type,
      :target_id,
      :target_type,
      :context,
      :origin,
      :deleted_at,
      :tag_id
    ])
    |> validate_required([:source_id, :source_type, :target_id, :target_type, :context])
    |> validate_inclusion(:source_type, @valid_types)
    |> validate_inclusion(:target_type, @valid_types)
    |> assoc_constraint(:tag)
    |> validate_change(:context, &Validation.validate_safe/2)
  end
end
