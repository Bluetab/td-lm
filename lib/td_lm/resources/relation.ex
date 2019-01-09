defmodule TdLm.Resources.Relation do
  @moduledoc """
  Module representing and entity relation in our database
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdLm.Resources.Tag

  schema "relations" do
    field :source_id, :string
    field :source_type, :string
    field :target_id, :string
    field :target_type, :string
    field :context, :map, default: %{}

    many_to_many(:tags, Tag,
      join_through: "relations_tags",
      on_delete: :delete_all
    )

    timestamps()
  end

  @doc false
  def changeset(relation, attrs) do
    relation
    |> cast(attrs, [:source_id, :source_type, :target_id, :target_type, :context])
    |> validate_required([:source_id, :source_type, :target_id, :target_type, :context])
  end
end
