defmodule TdLm.Resources.Tag do
  @moduledoc """
  Ecto Schema module for tags
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdLm.Resources.Relation

  schema "tags" do
    field(:value, :map, default: %{})

    many_to_many(:relations, Relation,
      join_through: "relations_tags",
      on_delete: :delete_all
    )

    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = tag, %{} = params) do
    tag
    |> cast(params, [:value])
    |> validate_required(:value)
    |> validate_change(:value, &Validation.validate_safe/2)
  end
end
