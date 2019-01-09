defmodule TdLm.Resources.Tag do
  @moduledoc """
  Entity to support the tag model
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdLm.Resources.Relation

  schema "tags" do
    field(:value, :map, default: %{})

    many_to_many(:relations, Relation,
      join_through: "relations_tags",
      on_delete: :delete_all
    )
    
    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:value])
    |> validate_required([:value])
  end
end
