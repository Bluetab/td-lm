defmodule TdLm.Resources.Tag do
  @moduledoc """
  Ecto Schema module for tags
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdLm.Resources.Relation

  @derive {Jason.Encoder, only: [:id, :value]}
  schema "tags" do
    field(:value, :map, default: %{})
    has_many(:relations, Relation)

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
