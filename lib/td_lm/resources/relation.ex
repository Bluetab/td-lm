defmodule TdLm.Resources.Relation do
  @moduledoc """
  Module representing and entity relation in our database
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "relations" do
    field :relation_type, :string
    field :source_id, :string
    field :source_type, :string
    field :target_id, :string
    field :target_type, :string
    field :context, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(relation, attrs) do
    relation
    |> cast(attrs, [:relation_type, :source_id, :source_type, :target_id, :target_type, :context])
    |> validate_required([:relation_type, :source_id, :source_type, :target_id, :target_type, :context])
  end
end
